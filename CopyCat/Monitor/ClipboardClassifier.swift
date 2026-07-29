import AppKit

struct ClipboardSnapshot {
    var types: [NSPasteboard.PasteboardType]
    var string: String?
    var pngData: Data?
    var fileURLs: [URL]
}

enum ClipboardClassifier {
    // Password managers mark sensitive entries with these UTIs; see nspasteboard.org.
    private static let ignoredTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    static func classify(
        _ snapshot: ClipboardSnapshot,
        source: RunningAppInfo?,
        excludedBundleIDs: Set<String>
    ) -> ClipboardCandidate? {
        guard Set(snapshot.types).isDisjoint(with: ignoredTypes) else { return nil }
        if let bundleID = source?.bundleID, excludedBundleIDs.contains(bundleID) { return nil }

        let content: ClipboardCandidate.Content
        if let url = snapshot.fileURLs.first {
            content = .fileURL(url)
        } else if let png = snapshot.pngData {
            content = .image(png)
        } else if let text = snapshot.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content = .text(text)
        } else {
            return nil
        }

        return ClipboardCandidate(
            content: content,
            sourceAppBundleID: source?.bundleID,
            sourceAppName: source?.name
        )
    }
}
