import AppKit

@MainActor
final class PasteService {
    private let imageStore: ImageStore

    init(imageStore: ImageStore) {
        self.imageStore = imageStore
    }

    func write(_ item: ClipboardItem, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .fileURL:
            if let path = item.text {
                pasteboard.writeObjects([NSURL.fileURL(withPath: path) as NSURL])
            }
        case .image:
            if let filename = item.imageFilename,
               let data = try? Data(contentsOf: imageStore.imageURL(for: filename)) {
                pasteboard.setData(data, forType: .png)
            }
        }
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // Paste by simulating ⌘V. The panel never activated our app, so the
    // keystroke lands in the app the user was working in.
    func sendPasteKeystroke() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey = CGKeyCode(9)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
