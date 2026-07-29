import AppKit

// Non-activating: the panel takes key status for typing in the search field,
// but never activates CopyKat, so the previous app keeps focus and ⌘V lands there.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // .floating sits below Spotlight and similar system overlays; .popUpMenu
        // keeps the panel on top of them, like other launcher-style panels.
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
}
