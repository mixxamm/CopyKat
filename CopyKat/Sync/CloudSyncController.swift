import CloudKit
import Foundation
import Observation
import os

// Sync through the user's own iCloud, on plain CloudKit operations. This began
// life on CKSyncEngine, but on current OS builds the engine's batches come
// back as HTTP 500 while direct operations sail through, so the controller
// drives the database itself: a diff against what was last sent, modify
// operations for the difference, and zone change tokens for the way back.
//
// The cloud is a transport, not the authority: records removed from iCloud
// (because a toggle changed or an item rolled out of scope) are never turned
// into local deletions. Local history only grows through sync.
@MainActor
@Observable
final class CloudSyncController {
    static let containerIdentifier = "iCloud.com.mixxamm.copykat"
    private static let batchSize = 40

    private let store: HistoryStore
    private let imageStore: ImageStore
    private let logger = Logger(subsystem: "com.mixxamm.copykat", category: "CloudSync")

    private var running = false
    private var reconcileScheduled = false
    private var syncing = false
    private var zoneReady = false
    private var periodicTask: Task<Void, Never>?

    // What the cloud has, by content hash, with the pin state that was sent.
    // Reconciling against this turns "the whole store" into a small diff.
    private var synced: [String: Bool] = [:]
    private let syncedURL: URL
    private let tokenURL: URL

    private(set) var lastError: String?

    // What the settings screens show: how much of the history is in iCloud.
    var syncedCount: Int { synced.count }

    // os_log proved unreadable on beta systems, so the engine keeps its own
    // small trace next to its state files. Trimmed on every start.
    private let traceURL: URL

    init(store: HistoryStore, imageStore: ImageStore, stateDirectory: URL) {
        self.store = store
        self.imageStore = imageStore
        self.syncedURL = stateDirectory.appendingPathComponent("cloudsync-sent.json")
        self.tokenURL = stateDirectory.appendingPathComponent("cloudsync-token.data")
        self.traceURL = stateDirectory.appendingPathComponent("cloudsync-trace.log")
        self.synced = (try? JSONDecoder().decode([String: Bool].self, from: Data(contentsOf: syncedURL))) ?? [:]
    }

    func trace(_ message: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
        if let handle = try? FileHandle(forWritingTo: traceURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            try? handle.close()
        } else {
            try? line.data(using: .utf8)!.write(to: traceURL)
        }
    }

    // CKContainer raises an uncatchable exception in a process signed without
    // the iCloud entitlement, so probe before touching it. A Developer ID
    // build without the provisioned capability degrades to a visible error
    // instead of a crash.
    static var entitlementPresent: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-services" as CFString, nil) != nil
        #else
        return true
        #endif
    }

    private var database: CKDatabase {
        CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase
    }

    func start() {
        guard SyncPolicy.current().enabled, !running else { return }
        guard Self.entitlementPresent else {
            lastError = String(localized: "This build was signed without iCloud capability.")
            logger.error("sync: missing iCloud entitlement, not starting")
            return
        }
        running = true
        try? FileManager.default.removeItem(at: traceURL)
        trace("sync started")

        // One-time full refetch: tokens minted during the ghost-record era
        // claim records were seen that never actually survived locally. The
        // content-hash dedupe makes re-applying everything harmless.
        let markerURL = tokenURL.deletingLastPathComponent().appendingPathComponent("cloudsync-refetch-2")
        if !FileManager.default.fileExists(atPath: markerURL.path) {
            saveToken(nil)
            try? Data().write(to: markerURL)
            trace("change token reset for a full refetch")
        }

        // Surface the one failure people actually hit: no iCloud account.
        Task { [weak self] in
            let status = try? await CKContainer(identifier: Self.containerIdentifier).accountStatus()
            await MainActor.run {
                guard let self else { return }
                switch status {
                case .available:
                    break
                case .noAccount:
                    self.lastError = String(localized: "Sign in to iCloud on this device to sync.")
                default:
                    self.lastError = String(localized: "iCloud is not available on this device right now.")
                }
            }
        }

        // Fetch shortly after start, then keep a slow heartbeat: pushes need
        // infrastructure this build does not carry, and a five minute poll is
        // plenty for a clipboard that syncs opportunistically.
        periodicTask = Task { [weak self] in
            await self?.sync()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.sync()
            }
        }
        scheduleReconcile()
    }

    func stop() {
        running = false
        periodicTask?.cancel()
        periodicTask = nil
    }

    // Pull-to-refresh: fetch whatever the other devices sent, right now.
    func fetchNow() async {
        if !running { start() }
        await sync()
    }

    // Called whenever the history or the policy moves. Debounced: a paste can
    // touch the store several times in one beat.
    func scheduleReconcile() {
        guard SyncPolicy.current().enabled else { return }
        if !running { start() }
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.reconcileScheduled = false
            await self?.sync()
        }
    }

    // One full pass: push the local difference, then pull the remote one.
    private func sync() async {
        guard running, !syncing else { return }
        syncing = true
        defer { syncing = false }
        do {
            try await ensureZone()
            try await push()
            try await pull()
            lastError = nil
        } catch {
            let flat = "\(error)".replacingOccurrences(of: "\n", with: " ")
            trace("sync FAILED: \(flat.prefix(400))")
            lastError = error.localizedDescription
        }
    }

    private func ensureZone() async throws {
        guard !zoneReady else { return }
        _ = try await database.save(CKRecordZone(zoneID: SyncRecordMapper.zoneID))
        zoneReady = true
        trace("zone ready")
    }

    private func push() async throws {
        let qualifying = SyncPolicy.current().qualifyingItems(in: store.items(matching: ""))
        // Tolerant of duplicate hashes: trapping on somebody's corrupt store
        // turns a data hiccup into a crash loop. A pin anywhere wins.
        let wanted = Dictionary(
            qualifying.filter { !$0.contentHash.isEmpty }.map { ($0.contentHash, $0.isPinned) },
            uniquingKeysWith: { $0 || $1 }
        )

        var toSave: [CKRecord] = []
        for (hash, pinned) in wanted where synced[hash] != pinned {
            guard let item = store.item(withContentHash: hash) else { continue }
            var imageURL: URL?
            if item.kind == .image, let filename = item.imageFilename {
                imageURL = imageStore.imageURL(for: filename)
            }
            toSave.append(SyncRecordMapper.record(for: item, imageFileURL: imageURL))
        }
        let toDelete = synced.keys.filter { wanted[$0] == nil }.map { SyncRecordMapper.recordID(for: $0) }
        guard !toSave.isEmpty || !toDelete.isEmpty else { return }
        trace("push: \(toSave.count) saves, \(toDelete.count) deletes")

        for chunk in stride(from: 0, to: max(toSave.count, 1), by: Self.batchSize) {
            let slice = Array(toSave[chunk..<min(chunk + Self.batchSize, toSave.count)])
            let deletions = chunk == 0 ? toDelete : []
            guard !slice.isEmpty || !deletions.isEmpty else { continue }
            let result = try await database.modifyRecords(
                saving: slice,
                deleting: deletions,
                savePolicy: .changedKeys,
                atomically: false
            )
            for (id, outcome) in result.saveResults {
                switch outcome {
                case .success(let record):
                    synced[id.recordName] = (record["isPinned"] as? Int ?? 0) == 1
                case .failure(let error):
                    trace("save failed \(id.recordName.prefix(12)): \(error.localizedDescription)")
                }
            }
            for (id, outcome) in result.deleteResults {
                if case .success = outcome {
                    synced.removeValue(forKey: id.recordName)
                }
            }
            persistSynced()
        }
        trace("push done, \(synced.count) in cloud")
    }

    private func pull() async throws {
        do {
            // CloudKit pages its change feed; without draining every page the
            // newest records, images most of all, simply never arrive.
            var moreComing = true
            var applied = 0
            while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: SyncRecordMapper.zoneID, since: loadToken())
            for modification in changes.modificationResultsByID.values {
                if case .success(let change) = modification {
                    // Only records that look like ours get near the store; the
                    // first sync pass once minted 165 empty ghosts out of
                    // records that did not survive this checkpoint.
                    let record = change.record
                    guard record.recordType == SyncRecordMapper.recordType,
                          !record.recordID.recordName.isEmpty,
                          let kindRaw = record["kind"] as? String,
                          let kind = ClipboardItemKind(rawValue: kindRaw),
                          kind != .text || ((record["text"] as? String)?.isEmpty == false)
                    else {
                        trace("pull: skipped \(record.recordType) \(record.recordID.recordName.prefix(24)) fields=\(record.allKeys().joined(separator: ","))")
                        continue
                    }
                    SyncRecordMapper.apply(record, to: store, imageStore: imageStore)
                    // Records written by another device are, by definition,
                    // already in the cloud; count them so this device does not
                    // try to push them straight back.
                    let pinned = (change.record["isPinned"] as? Int ?? 0) == 1
                    synced[change.record.recordID.recordName] = pinned
                    applied += 1
                }
            }
            // Deletions stay cloud-side by design; see the header.
            persistSynced()
            saveToken(changes.changeToken)
            moreComing = changes.moreComing
            }
            if applied > 0 {
                trace("pull: applied \(applied) records")
            }
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            zoneReady = false
            saveToken(nil)
        }
    }

    // MARK: - State on disk

    private func persistSynced() {
        if let data = try? JSONEncoder().encode(synced) {
            try? data.write(to: syncedURL, options: .atomic)
        }
    }

    private func loadToken() -> CKServerChangeToken? {
        guard let data = try? Data(contentsOf: tokenURL) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveToken(_ token: CKServerChangeToken?) {
        guard let token,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else {
            try? FileManager.default.removeItem(at: tokenURL)
            return
        }
        try? data.write(to: tokenURL, options: .atomic)
    }
}
