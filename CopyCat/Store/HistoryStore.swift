import Foundation
import SwiftData
import os

@MainActor
final class HistoryStore {
    private let context: ModelContext
    private let imageStore: ImageStore
    private let logger = Logger(subsystem: "dev.mixxamm.CopyCat", category: "HistoryStore")

    var maxItems = 200

    init(container: ModelContainer, imageStore: ImageStore) {
        self.context = ModelContext(container)
        self.imageStore = imageStore
    }

    @discardableResult
    func add(_ candidate: ClipboardCandidate) throws -> ClipboardItem {
        let item: ClipboardItem
        switch candidate.content {
        case .text(let text):
            item = ClipboardItem(kind: .text, text: text, contentHash: "text:\(text)")
        case .fileURL(let url):
            item = ClipboardItem(kind: .fileURL, text: url.path, contentHash: "file:\(url.path)")
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
            existing.createdAt = .now
            try context.save()
            return existing
        }

        item.sourceAppBundleID = candidate.sourceAppBundleID
        item.sourceAppName = candidate.sourceAppName
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
        try? context.save()
    }

    func delete(_ item: ClipboardItem) {
        if let filename = item.imageFilename {
            imageStore.delete(named: filename)
        }
        context.delete(item)
        try? context.save()
    }

    func deleteAll() {
        for item in allItemsNewestFirst() where !item.isPinned {
            delete(item)
        }
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
