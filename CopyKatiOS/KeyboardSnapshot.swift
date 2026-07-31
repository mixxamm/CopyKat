import Foundation

// What the keyboard extension shows. It cannot read the live store: without
// Full Access a keyboard may only read the app group, and SQLite in WAL mode
// needs write access even to read. So the app writes this snapshot whenever
// the history changes, and the keyboard reads nothing else.
struct KeyboardSnapshot: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id: String { contentHash }
        let contentHash: String
        let text: String
        let isPinned: Bool
    }

    var entries: [Entry] = []

    static let maxEntries = 100

    static func url(in container: URL) -> URL {
        container.appendingPathComponent("CopyKat", isDirectory: true)
            .appendingPathComponent("keyboard-snapshot.json")
    }

    static func write(items: [ClipboardItem], to container: URL) {
        // Text only, by design: the document proxy a keyboard types through
        // carries nothing else.
        let entries = items.lazy
            .filter { $0.kind == .text || $0.kind == .fileURL }
            .compactMap { item -> Entry? in
                guard let text = item.text, !text.isEmpty else { return nil }
                return Entry(contentHash: item.contentHash, text: text, isPinned: item.isPinned)
            }
            .prefix(maxEntries)
        let snapshot = KeyboardSnapshot(entries: Array(entries))
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url(in: container), options: .atomic)
    }

    static func read(from container: URL) -> KeyboardSnapshot {
        guard let data = try? Data(contentsOf: url(in: container)),
              let snapshot = try? JSONDecoder().decode(KeyboardSnapshot.self, from: data)
        else { return KeyboardSnapshot() }
        return snapshot
    }
}

enum AppGroup {
    static let identifier = "group.com.mixxamm.copykat"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
