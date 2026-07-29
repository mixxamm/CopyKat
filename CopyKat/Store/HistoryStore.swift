import CryptoKit
import Foundation
import SwiftData
import os

@MainActor
final class HistoryStore {
    private let context: ModelContext
    private let imageStore: ImageStore
    private let logger = Logger(subsystem: "dev.mixxamm.CopyKat", category: "HistoryStore")

    var maxItems = 200
    var pinsChanged: (() -> Void)?

    init(container: ModelContainer, imageStore: ImageStore) {
        self.context = ModelContext(container)
        self.imageStore = imageStore
    }

    @discardableResult
    func add(_ candidate: ClipboardCandidate) throws -> ClipboardItem {
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

        if let existing = try existingItem(withHash: item.contentHash) {
            // CopyKat's own paste is re-captured by the monitor and collapses into this
            // existing row via dedupe. We deliberately keep the row's original
            // source-app attribution here rather than overwriting it with whatever
            // app was pasted into, otherwise every paste would re-attribute the item.
            existing.createdAt = .now
            try context.save()
            return existing
        }

        item.sourceAppBundleID = candidate.sourceAppBundleID
        item.sourceAppName = candidate.sourceAppName
        item.isRemote = candidate.isRemote
        context.insert(item)
        trim()
        try context.save()
        return item
    }

    func items(matching query: String) -> [ClipboardItem] {
        let all = allItemsNewestFirst()
        let filtered: [ClipboardItem]
        if query.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                ($0.text?.localizedCaseInsensitiveContains(query) ?? false)
                    || ($0.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        item.pinShortcutID = item.isPinned ? UUID().uuidString : nil
        try? context.save()
        pinsChanged?()
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
        let unpinned = allItemsNewestFirst().filter { !$0.isPinned }
        for item in unpinned.dropFirst(maxItems) {
            if let filename = item.imageFilename {
                imageStore.delete(named: filename)
            }
            context.delete(item)
        }
    }
}
