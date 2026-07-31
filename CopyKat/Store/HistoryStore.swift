import CryptoKit
import Foundation
import SwiftData
import os

@MainActor
final class HistoryStore {
    private let context: ModelContext
    private let imageStore: ImageStore
    private let logger = Logger(subsystem: "com.mixxamm.copykat", category: "HistoryStore")
    private let matcher = FuzzyMatcher()

    // nil keeps everything; the user can turn the cap off in settings.
    var maxItems: Int? = 200
    private let imageIndexer = ImageIndexer()
    var pinsChanged: (() -> Void)?
    // Anything that moved the history: adds, deletes, pins, undo, insights.
    // The sync engine listens here.
    var historyChanged: (() -> Void)?
    var selfWriteTracker: SelfWriteTracker?
    // Fires for copies the user actually made, so callers can drop state that
    // only made sense for the previous clipboard content.
    var externalCopyArrived: (() -> Void)?

    init(container: ModelContainer, imageStore: ImageStore) {
        self.context = ModelContext(container)
        self.imageStore = imageStore
    }

    @discardableResult
    func add(_ candidate: ClipboardCandidate) throws -> ClipboardItem? {
        let item: ClipboardItem
        switch candidate.content {
        case .text(let text):
            item = ClipboardItem(kind: .text, text: text, contentHash: "text:\(Self.sha256Hex(text))")
        case .fileURL(let url):
            item = ClipboardItem(kind: .fileURL, text: url.path, contentHash: "file:\(Self.sha256Hex(url.path))")
        case .image(let data):
            let saved = try imageStore.save(pngData: data)
            item = ClipboardItem(
                kind: .image,
                imageFilename: saved.filename,
                imageWidth: saved.width,
                imageHeight: saved.height,
                contentHash: "image:\(saved.hash)"
            )
        }

        let isOurOwnPaste = selfWriteTracker?.isOurOwnWrite(hash: item.contentHash) == true
        if !isOurOwnPaste {
            externalCopyArrived?()
        }

        if let existing = try existingItem(withHash: item.contentHash) {
            // A re-copy moves the item back to the top, but our own paste must
            // leave the history exactly as it was: same position, same source
            // app attribution (the app pasted into is not where it came from).
            if !isOurOwnPaste {
                existing.createdAt = .now
                try context.save()
            }
            return existing
        }

        // Content we just wrote ourselves that is not in the history: pasting
        // an image as its recognized text. Recording that as a copy would grow
        // the history as a side effect of pasting, so it is dropped entirely.
        if isOurOwnPaste {
            return nil
        }

        item.sourceAppBundleID = candidate.sourceAppBundleID
        item.sourceAppName = candidate.sourceAppName
        item.isRemote = candidate.isRemote
        item.fileBookmark = candidate.fileBookmark
        context.insert(item)
        trim()
        try context.save()
        indexInBackground(item)
        historyChanged?()
        return item
    }

    func item(withContentHash hash: String) -> ClipboardItem? {
        try? existingItem(withHash: hash)
    }

    // A record arriving from another device. It bypasses the capture path on
    // purpose: no self-write suppression, no re-indexing, no reordering.
    @discardableResult
    func insertSynced(
        contentHash: String,
        kind: ClipboardItemKind,
        text: String?,
        imageData: Data?,
        createdAt: Date,
        isPinned: Bool,
        sourceAppName: String?,
        insights: ImageInsights
    ) -> ClipboardItem? {
        guard (try? existingItem(withHash: contentHash)) == nil else { return nil }

        var imageFilename: String?
        var width: Int?
        var height: Int?
        if kind == .image {
            guard let imageData, let saved = try? imageStore.save(pngData: imageData) else { return nil }
            imageFilename = saved.filename
            width = saved.width
            height = saved.height
        }

        let item = ClipboardItem(
            kind: kind,
            text: text,
            imageFilename: imageFilename,
            imageWidth: width,
            imageHeight: height,
            contentHash: contentHash,
            sourceAppName: sourceAppName,
            createdAt: createdAt,
            isPinned: isPinned
        )
        item.isRemote = true
        item.recognizedText = insights.recognizedText
        item.qrPayload = insights.qrPayload
        item.imageLabels = insights.labels.isEmpty ? nil : insights.labels.joined(separator: " ")
        item.visionIndexed = true
        if isPinned {
            item.pinShortcutID = UUID().uuidString
        }
        context.insert(item)
        trim()
        try? context.save()
        if isPinned {
            pinsChanged?()
        }
        historyChanged?()
        return item
    }

    // MARK: - Vision indexing

    // What Vision found becomes part of the item, so search can see into images.
    func applyInsights(_ insights: ImageInsights, to item: ClipboardItem) {
        item.recognizedText = insights.recognizedText
        item.qrPayload = insights.qrPayload
        item.imageLabels = insights.labels.isEmpty ? nil : insights.labels.joined(separator: " ")
        item.visionIndexed = true
        try? context.save()
        historyChanged?()
    }

    // One image at a time. Vision's first request in a process spends ~30s
    // loading its models, and a launch-time backfill that fires everything at
    // once starves the cooperative thread pool: nothing ever finishes, new
    // captures queue behind the pile-up, and search never learns a thing.
    private var indexQueue: [PersistentIdentifier] = []
    private var indexRunning = false
    // Off in unit tests, where background OCR racing the assertions would make
    // results depend on timing.
    var visionIndexingEnabled = true

    private func indexInBackground(_ item: ClipboardItem) {
        guard visionIndexingEnabled, AppSettings.indexImageContent,
              item.kind == .image, !item.visionIndexed, item.imageFilename != nil
        else { return }
        let id = item.persistentModelID
        guard !indexQueue.contains(id) else { return }
        indexQueue.append(id)
        logger.notice("vision: queued, depth \(self.indexQueue.count)")
        drainIndexQueue()
    }

    private func drainIndexQueue() {
        guard !indexRunning, !indexQueue.isEmpty else { return }
        indexRunning = true
        let id = indexQueue.removeFirst()
        let indexer = imageIndexer
        Task { [weak self] in
            defer {
                self?.indexRunning = false
                self?.drainIndexQueue()
            }
            guard let self, let item = self.item(withID: id), !item.visionIndexed,
                  let filename = item.imageFilename
            else { return }
            guard let data = try? Data(contentsOf: self.imageStore.imageURL(for: filename)) else {
                self.logger.error("vision: unreadable \(filename, privacy: .public)")
                return
            }
            // Off the main actor: accurate OCR takes real time per image.
            let insights = await Task.detached(priority: .utility) {
                indexer.insights(for: data)
            }.value
            guard let live = self.item(withID: id) else { return }
            self.applyInsights(insights, to: live)
            self.logger.notice("vision: indexed chars=\(insights.recognizedText?.count ?? 0) labels=\(insights.labels.count), \(self.indexQueue.count) left")
        }
    }

    // Histories that predate the indexer have images Vision never saw.
    func backfillVisionIndex() {
        guard AppSettings.indexImageContent else { return }
        for item in allItemsNewestFirst() where item.kind == .image && !item.visionIndexed {
            indexInBackground(item)
        }
    }

    private func item(withID id: PersistentIdentifier) -> ClipboardItem? {
        allItemsNewestFirst().first { $0.persistentModelID == id }
    }

    func items(matching query: String) -> [ClipboardItem] {
        let all = allItemsNewestFirst()
        let filtered: [ClipboardItem]
        if query.isEmpty {
            filtered = all
        } else {
            // Fuzzy match on content and source app; best score first, and
            // recency breaks ties because `all` is already newest first. Images
            // join in through what Vision read out of them.
            let scored = all.compactMap { item -> (ClipboardItem, Double)? in
                let haystacks = [
                    item.text, item.sourceAppName,
                    item.recognizedText, item.qrPayload, item.imageLabels,
                ].compactMap { $0 }
                let best = haystacks.compactMap { matcher.score(query, in: $0) }.max()
                guard let best, best > 0 else { return nil }
                return (item, best)
            }
            filtered = scored.sorted { $0.1 > $1.1 }.map(\.0)
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        item.pinShortcutID = item.isPinned ? UUID().uuidString : nil
        try? context.save()
        pinsChanged?()
        historyChanged?()
    }

    func delete(_ item: ClipboardItem) {
        let wasPinned = item.isPinned
        if let filename = item.imageFilename {
            imageStore.delete(named: filename)
        }
        context.delete(item)
        try? context.save()
        if wasPinned {
            pinsChanged?()
        }
        historyChanged?()
    }

    // Everything needed to put a row back. The SwiftData object is gone once
    // deleted, so the values have to be copied out before that happens.
    private struct DeletedItem {
        var kind: ClipboardItemKind
        var text: String?
        var imageFilename: String?
        var imageWidth: Int?
        var imageHeight: Int?
        var contentHash: String
        var sourceAppBundleID: String?
        var sourceAppName: String?
        var createdAt: Date
        var isPinned: Bool
        var pinShortcutID: String?
        var isRemote: Bool
        var fileBookmark: Data?
        var recognizedText: String?
        var qrPayload: String?
        var imageLabels: String?
        var visionIndexed: Bool
        var deletedAt: Date
    }

    static let undoWindow: TimeInterval = 60
    private var recentlyDeleted: [DeletedItem] = []

    var canUndoDelete: Bool {
        forgetExpiredDeletions()
        return !recentlyDeleted.isEmpty
    }

    // Deleting by hand is a keystroke away, so it stays reversible for a while.
    // The image file is kept back until the window closes; restoring a picture
    // whose bytes are gone would put an empty row back.
    func deleteUndoably(_ item: ClipboardItem, at date: Date = .now) {
        forgetExpiredDeletions()
        recentlyDeleted.append(
            DeletedItem(
                kind: item.kind,
                text: item.text,
                imageFilename: item.imageFilename,
                imageWidth: item.imageWidth,
                imageHeight: item.imageHeight,
                contentHash: item.contentHash,
                sourceAppBundleID: item.sourceAppBundleID,
                sourceAppName: item.sourceAppName,
                createdAt: item.createdAt,
                isPinned: item.isPinned,
                pinShortcutID: item.pinShortcutID,
                isRemote: item.isRemote,
                fileBookmark: item.fileBookmark,
                recognizedText: item.recognizedText,
                qrPayload: item.qrPayload,
                imageLabels: item.imageLabels,
                visionIndexed: item.visionIndexed,
                deletedAt: date
            )
        )

        let wasPinned = item.isPinned
        context.delete(item)
        try? context.save()
        if wasPinned {
            pinsChanged?()
        }
        historyChanged?()
    }

    // Returns the restored row so the panel can highlight it again.
    @discardableResult
    func undoLastDelete(at date: Date = .now) -> ClipboardItem? {
        forgetExpiredDeletions(at: date)
        guard let deleted = recentlyDeleted.popLast() else { return nil }

        // The same content may have been copied again while the undo was still
        // open; a second row with that hash would never dedupe away.
        if let existing = try? existingItem(withHash: deleted.contentHash) {
            existing.isPinned = deleted.isPinned || existing.isPinned
            existing.pinShortcutID = existing.isPinned
                ? (existing.pinShortcutID ?? deleted.pinShortcutID ?? UUID().uuidString)
                : nil
            try? context.save()
            if existing.isPinned {
                pinsChanged?()
            }
            return existing
        }

        let item = ClipboardItem(
            kind: deleted.kind,
            text: deleted.text,
            imageFilename: deleted.imageFilename,
            imageWidth: deleted.imageWidth,
            imageHeight: deleted.imageHeight,
            contentHash: deleted.contentHash,
            sourceAppBundleID: deleted.sourceAppBundleID,
            sourceAppName: deleted.sourceAppName,
            createdAt: deleted.createdAt,
            isPinned: deleted.isPinned
        )
        item.pinShortcutID = deleted.pinShortcutID
        item.isRemote = deleted.isRemote
        item.fileBookmark = deleted.fileBookmark
        item.recognizedText = deleted.recognizedText
        item.qrPayload = deleted.qrPayload
        item.imageLabels = deleted.imageLabels
        item.visionIndexed = deleted.visionIndexed
        context.insert(item)
        try? context.save()
        if item.isPinned {
            pinsChanged?()
        }
        historyChanged?()
        return item
    }

    private func forgetExpiredDeletions(at date: Date = .now) {
        let expired = recentlyDeleted.filter { date.timeIntervalSince($0.deletedAt) > Self.undoWindow }
        recentlyDeleted.removeAll { date.timeIntervalSince($0.deletedAt) > Self.undoWindow }

        for filename in Set(expired.compactMap(\.imageFilename)) {
            // An identical image copied again since points at the same file,
            // and that row is still alive.
            let stillReferenced = allItemsNewestFirst().contains { $0.imageFilename == filename }
            if !stillReferenced {
                imageStore.delete(named: filename)
            }
        }
    }

    struct StorageUsage {
        var textItems = 0
        var imageItems = 0
        var imageBytes: Int64 = 0
        var databaseBytes: Int64 = 0

        var totalBytes: Int64 { imageBytes + databaseBytes }
    }

    func storageUsage() -> StorageUsage {
        var usage = StorageUsage()
        for item in allItemsNewestFirst() {
            if item.kind == .image {
                usage.imageItems += 1
            } else {
                usage.textItems += 1
            }
        }
        usage.imageBytes = imageStore.totalBytes()
        usage.databaseBytes = databaseBytes
        return usage
    }

    // Pinned items are spared: they are kept on purpose, however old they are.
    // Images are the only kind that costs real disk space, so they can be swept
    // on their own without touching the text you came for.
    @discardableResult
    func deleteItems(olderThan cutoff: Date, imagesOnly: Bool = false) -> Int {
        let stale = allItemsNewestFirst().filter { item in
            guard !item.isPinned, item.createdAt < cutoff else { return false }
            return imagesOnly ? item.kind == .image : true
        }
        for item in stale {
            delete(item)
        }
        return stale.count
    }

    func pinnedItems() -> [ClipboardItem] {
        allItemsNewestFirst().filter(\.isPinned)
    }

    // Items pinned before pin shortcuts existed have no shortcut ID; without
    // one the Pins settings tab cannot show a recorder for them.
    func backfillPinShortcutIDs() {
        for item in pinnedItems() where item.pinShortcutID == nil {
            item.pinShortcutID = UUID().uuidString
        }
        try? context.save()
    }

    func deleteAll() {
        for item in allItemsNewestFirst() where !item.isPinned {
            delete(item)
        }
    }

    // Early builds stored the raw text in contentHash instead of a digest. Rows
    // with the old format never dedupe against new copies, so every paste of such
    // a row would create a duplicate. Rewrite them once at launch and collapse
    // any duplicates that already slipped in.
    func migrateLegacyContentHashes() {
        for item in allItemsNewestFirst() {
            let expected: String?
            switch item.kind {
            case .text:
                expected = item.text.map { "text:\(Self.sha256Hex($0))" }
            case .fileURL:
                expected = item.text.map { "file:\(Self.sha256Hex($0))" }
            case .image:
                expected = nil
            }
            guard let expected, item.contentHash != expected else { continue }
            if let existing = try? existingItem(withHash: expected) {
                existing.createdAt = max(existing.createdAt, item.createdAt)
                existing.isPinned = existing.isPinned || item.isPinned
                context.delete(item)
            } else {
                item.contentHash = expected
            }
        }
        try? context.save()
    }

    func pruneOrphans() {
        var referenced = Set<String>()
        for item in allItemsNewestFirst() where item.kind == .image {
            guard let filename = item.imageFilename,
                  FileManager.default.fileExists(atPath: imageStore.imageURL(for: filename).path)
            else {
                context.delete(item)
                continue
            }
            referenced.insert(filename)
        }
        try? context.save()
        for stray in imageStore.existingFilenames().subtracting(referenced) {
            imageStore.delete(named: stray)
        }
    }

    private var databaseBytes: Int64 {
        guard let url = context.container.configurations.first?.url else { return 0 }
        // SwiftData keeps a write-ahead log and a shared memory file next to the
        // store; all three count towards what the history costs on disk.
        return ["", "-wal", "-shm"].reduce(into: Int64(0)) { total, suffix in
            let path = url.path + suffix
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int64
            total += size ?? 0
        }
    }

    private func allItemsNewestFirst() -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetch failed: \(error)")
            return []
        }
    }

    private static func sha256Hex(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func existingItem(withHash hash: String) throws -> ClipboardItem? {
        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func trim() {
        guard let maxItems else { return }
        let unpinned = allItemsNewestFirst().filter { !$0.isPinned }
        for item in unpinned.dropFirst(maxItems) {
            if let filename = item.imageFilename {
                imageStore.delete(named: filename)
            }
            context.delete(item)
        }
    }
}
