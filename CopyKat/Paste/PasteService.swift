import AppKit

@MainActor
final class PasteService {
    private let imageStore: ImageStore
    let selfWriteTracker = SelfWriteTracker()

    init(imageStore: ImageStore) {
        self.imageStore = imageStore
    }

    // Resolves the payload before touching the pasteboard, so a missing image
    // file or nil text never leaves the user's existing clipboard wiped and empty.
    @discardableResult
    func write(_ item: ClipboardItem, to pasteboard: NSPasteboard = .general) -> Bool {
        let written: Bool
        switch item.kind {
        case .text:
            guard let text = item.text else { return false }
            pasteboard.clearContents()
            written = pasteboard.setString(text, forType: .string)
        case .fileURL:
            guard let path = item.text else { return false }
            // Under the sandbox the app has no standing access to the file, so
            // the bookmark taken at copy time is what makes the pasted URL
            // usable by the receiving app.
            let url = resolvedFileURL(for: item) ?? URL(fileURLWithPath: path)
            let scoped = url.startAccessingSecurityScopedResource()
            pasteboard.clearContents()
            written = pasteboard.writeObjects([url as NSURL])
            if scoped {
                releaseScopedAccess(for: url)
            }
        case .image:
            guard let filename = item.imageFilename,
                  let data = try? Data(contentsOf: imageStore.imageURL(for: filename))
            else { return false }
            pasteboard.clearContents()
            written = pasteboard.setData(data, forType: .png)
        }
        // Pasting must not reorder history, so the store ignores this content
        // when it comes back around through the monitor.
        selfWriteTracker.record(hash: item.contentHash)
        return written
    }

    private func resolvedFileURL(for item: ClipboardItem) -> URL? {
        guard let bookmark = item.fileBookmark else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    // The receiving app needs a moment to claim the file before we drop our
    // own access to it.
    private func releaseScopedAccess(for url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // Deep link straight to the Accessibility pane; unlike the AX prompt this
    // also navigates a System Settings window that is already open elsewhere.
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // Paste by simulating ⌘V. The panel never activated our app, so the
    // keystroke lands in the app the user was working in.
    func sendPasteKeystroke() {
        postWhenKeyboardIsIdle(waited: 0)
    }

    private func postWhenKeyboardIsIdle(waited: TimeInterval) {
        guard !PasteKeystrokeGate.shouldPost(flags: NSEvent.modifierFlags, waited: waited) else {
            postPasteKeystroke()
            return
        }
        let step: TimeInterval = 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + step) { [weak self] in
            self?.postWhenKeyboardIsIdle(waited: waited + step)
        }
    }

    private func postPasteKeystroke() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateRemoteMouseDrag
        )
        let vKey = CGKeyCode(9)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        let tap = PasteKeystrokeGate.tap(flags: NSEvent.modifierFlags)
        down?.post(tap: tap)
        up?.post(tap: tap)
    }
}
