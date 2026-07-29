import AppKit

// NSPasteboard has no change notifications, so we poll changeCount on a timer.
// 0.2s is fast enough to feel instant and cheap enough to be invisible in Activity Monitor.
@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let onCapture: (ClipboardCandidate) -> Void
    private var timer: Timer?
    private var lastChangeCount: Int

    init(onCapture: @escaping (ClipboardCandidate) -> Void) {
        self.onCapture = onCapture
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let snapshot = ClipboardSnapshot(
            types: pasteboard.types ?? [],
            string: pasteboard.string(forType: .string),
            pngData: readImageData(),
            fileURLs: (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        )
        let frontmost = NSWorkspace.shared.frontmostApplication
        let source = frontmost.map {
            RunningAppInfo(bundleID: $0.bundleIdentifier, name: $0.localizedName)
        }
        if let candidate = ClipboardClassifier.classify(
            snapshot,
            source: source,
            excludedBundleIDs: AppSettings.effectiveExcludedBundleIDs
        ) {
            onCapture(candidate)
        }
    }

    private func readImageData() -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        guard let tiff = pasteboard.data(forType: .tiff),
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
