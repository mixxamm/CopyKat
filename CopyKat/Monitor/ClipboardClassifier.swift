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

    // Set by macOS on Universal Clipboard content copied on another device.
    private static let remoteType = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")

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

        // The frontmost Mac app has nothing to do with content copied on
        // another device, so remote items carry no source attribution.
        let isRemote = snapshot.types.contains(Self.remoteType)
        return ClipboardCandidate(
            content: content,
            sourceAppBundleID: isRemote ? nil : source?.bundleID,
            sourceAppName: isRemote ? nil : source?.name,
            isRemote: isRemote
        )
    }
}
