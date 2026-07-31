import CloudKit
import Foundation
import Observation
import os

// Sync through the user's own iCloud, built on CKSyncEngine. This is not
// SwiftData's automatic mirroring on purpose: mirroring is all-or-nothing,
// and the whole point here is that the user chooses what leaves the machine.
//
// The cloud is a transport, not the authority: records removed from iCloud
// (because a toggle changed or an item rolled out of scope) are never turned
// into local deletions. Local history only grows through sync.
@MainActor
@Observable
final class CloudSyncController {
    static let containerIdentifier = "iCloud.com.mixxamm.copykat"

    private let store: HistoryStore
    private let imageStore: ImageStore
    private let stateURL: URL
    private let logger = Logger(subsystem: "com.mixxamm.copykat", category: "CloudSync")

    private var engine: CKSyncEngine?
    private var reconcileScheduled = false
    // What the cloud has, by content hash, with the pin state that was sent.
    // Reconciling against this turns "the whole store" into a small diff.
    private var synced: [String: Bool] = [:]
    private let syncedURL: URL

    private(set) var lastError: String?

    // What the settings screens show: how much of the history is in iCloud.
    var syncedCount: Int { synced.count }

    init(store: HistoryStore, imageStore: ImageStore, stateDirectory: URL) {
        self.store = store
        self.imageStore = imageStore
        self.stateURL = stateDirectory.appendingPathComponent("cloudsync-state.data")
        self.syncedURL = stateDirectory.appendingPathComponent("cloudsync-sent.json")
        self.synced = (try? JSONDecoder().decode([String: Bool].self, from: Data(contentsOf: syncedURL))) ?? [:]
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

    func start() {
        guard SyncPolicy.current().enabled, engine == nil else { return }
        guard Self.entitlementPresent else {
            lastError = String(localized: "This build was signed without iCloud capability.")
            logger.error("sync: missing iCloud entitlement, not starting")
            return
        }
        var configuration = CKSyncEngine.Configuration(
            database: CKContainer(identifier: Self.containerIdentifier).privateCloudDatabase,
            stateSerialization: loadState(),
            delegate: Delegate(controller: self)
        )
        configuration.automaticallySync = true
        engine = CKSyncEngine(configuration)
        scheduleReconcile()

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
    }

    func stop() {
        engine = nil
    }

    // Pull-to-refresh: fetch whatever the other devices sent, right now.
    func fetchNow() async {
        if engine == nil { start() }
        try? await engine?.fetchChanges()
        try? await engine?.sendChanges()
    }

    // Called whenever the history or the policy moves. Debounced: a paste can
    // touch the store several times in one beat.
    func scheduleReconcile() {
        guard SyncPolicy.current().enabled else { return }
        if engine == nil { start() }
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.reconcileScheduled = false
            self?.reconcile()
        }
    }

    private func reconcile() {
        guard let engine else { return }
        let qualifying = SyncPolicy.current().qualifyingItems(in: store.items(matching: ""))
        let wanted = Dictionary(uniqueKeysWithValues: qualifying.map { ($0.contentHash, $0.isPinned) })

        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for (hash, pinned) in wanted where synced[hash] != pinned {
            changes.append(.saveRecord(SyncRecordMapper.recordID(for: hash)))
        }
        for hash in synced.keys where wanted[hash] == nil {
            changes.append(.deleteRecord(SyncRecordMapper.recordID(for: hash)))
        }
        guard !changes.isEmpty else { return }
        logger.notice("sync: scheduling \(changes.count) changes")
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncRecordMapper.zoneID))])
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    // MARK: - Engine plumbing

    private func loadState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func saveState(_ serialization: CKSyncEngine.State.Serialization) {
        if let data = try? JSONEncoder().encode(serialization) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    private func persistSynced() {
        if let data = try? JSONEncoder().encode(synced) {
            try? data.write(to: syncedURL, options: .atomic)
        }
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let item = store.item(withContentHash: recordID.recordName) else { return nil }
        var imageURL: URL?
        if item.kind == .image, let filename = item.imageFilename {
            imageURL = imageStore.imageURL(for: filename)
        }
        return SyncRecordMapper.record(for: item, imageFileURL: imageURL)
    }

    private final class Delegate: CKSyncEngineDelegate {
        // The controller owns the delegate's lifetime through the engine.
        private weak var controller: CloudSyncController?

        init(controller: CloudSyncController) {
            self.controller = controller
        }

        func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
            await MainActor.run {
                guard let controller else { return }
                switch event {
                case .stateUpdate(let update):
                    controller.saveState(update.stateSerialization)
                case .fetchedRecordZoneChanges(let changes):
                    for modification in changes.modifications {
                        SyncRecordMapper.apply(modification.record, to: controller.store, imageStore: controller.imageStore)
                    }
                    // Deletions stay cloud-side by design; see the header.
                case .sentRecordZoneChanges(let sent):
                    for saved in sent.savedRecords {
                        let pinned = (saved["isPinned"] as? Int ?? 0) == 1
                        controller.synced[saved.recordID.recordName] = pinned
                    }
                    for deleted in sent.deletedRecordIDs {
                        controller.synced.removeValue(forKey: deleted.recordName)
                    }
                    for failure in sent.failedRecordSaves {
                        controller.lastError = failure.error.localizedDescription
                        controller.logger.error("sync: save failed \(failure.error.localizedDescription, privacy: .public)")
                    }
                    controller.persistSynced()
                case .accountChange:
                    controller.synced = [:]
                    controller.persistSynced()
                    controller.scheduleReconcile()
                default:
                    break
                }
            }
        }

        func nextRecordZoneChangeBatch(
            _ context: CKSyncEngine.SendChangesContext,
            syncEngine: CKSyncEngine
        ) async -> CKSyncEngine.RecordZoneChangeBatch? {
            let pending = syncEngine.state.pendingRecordZoneChanges
            guard !pending.isEmpty else { return nil }
            return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
                await MainActor.run { self.controller?.record(for: recordID) }
            }
        }
    }
}
