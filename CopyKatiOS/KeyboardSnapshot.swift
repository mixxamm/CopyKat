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
        // Set for image items: the filename inside the shared Images folder.
        // The keyboard renders the thumbnail itself; pasting the image needs
        // Full Access, so without it these entries stay hidden.
        var imageFilename: String? = nil
        // Portrait images get a taller cell in the keyboard. Optional so
        // snapshots written before this field existed still decode.
        var isPortrait: Bool? = nil
    }

    var entries: [Entry] = []

    static let maxEntries = 100

    static func url(in container: URL) -> URL {
        container.appendingPathComponent("CopyKat", isDirectory: true)
            .appendingPathComponent("keyboard-snapshot.json")
    }

    static func write(items: [ClipboardItem], to container: URL) {
        // Text inserts through the document proxy; images can only travel via
        // the pasteboard, which the keyboard offers when Full Access is on.
        let entries = items.lazy
            .compactMap { item -> Entry? in
                switch item.kind {
                case .text, .fileURL:
                    guard let text = item.text, !text.isEmpty else { return nil }
                    return Entry(contentHash: item.contentHash, text: text, isPinned: item.isPinned)
                case .image:
                    guard let filename = item.imageFilename else { return nil }
                    // Orientation only when both dimensions are known; the
                    // keyboard falls back to the compact cell otherwise.
                    var isPortrait: Bool? = nil
                    if let width = item.imageWidth, let height = item.imageHeight {
                        isPortrait = height > width
                    }
                    return Entry(
                        contentHash: item.contentHash,
                        text: item.recognizedText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "",
                        isPinned: item.isPinned,
                        imageFilename: filename,
                        isPortrait: isPortrait
                    )
                }
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
