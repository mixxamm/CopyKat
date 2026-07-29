import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let viewModel: PanelViewModel

    init(
        viewModel: PanelViewModel,
        imageStore: ImageStore,
        onCommit: @escaping (ClipboardItem) -> Void
    ) {
        self.viewModel = viewModel
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 440))
        super.init()

        let view = PanelView(
            model: viewModel,
            imageStore: imageStore,
            onCommit: onCommit,
            onDismiss: { [weak self] in self?.hide() }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self
    }

    var isPanelVisible: Bool { panel.isVisible }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        viewModel.reset()
        centerOnActiveScreen()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func centerOnActiveScreen() {
        let screenUnderMouse = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }
        guard let screen = screenUnderMouse ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2 + frame.height * 0.08
        )
        panel.setFrameOrigin(origin)
    }
}
