import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel
    private let viewModel: PanelViewModel
    private let onCommit: (ClipboardItem) -> Void
    private var tapTracker = FastPasteTapTracker()
    private var flagsMonitor: Any?
    private var escapeMonitor: Any?

    init(
        viewModel: PanelViewModel,
        imageStore: ImageStore,
        onCommit: @escaping (ClipboardItem) -> Void,
        onRecordShortcut: @escaping (ClipboardItem) -> Void
    ) {
        self.viewModel = viewModel
        self.onCommit = onCommit
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 440))
        super.init()

        let view = PanelView(
            model: viewModel,
            imageStore: imageStore,
            onCommit: onCommit,
            onDismiss: { [weak self] in self?.hide() },
            onRecordShortcut: { [weak self] item in
                self?.hide()
                onRecordShortcut(item)
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self

        // Fast paste: releasing every modifier commits the selection. The
        // panel is key while visible, so a local monitor sees the release.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if let self, self.viewModel.isFastSession,
               event.modifierFlags.intersection([.command, .shift, .control, .option]).isEmpty {
                self.commitFastSelection()
            }
            return event
        }

        // Escape always cancels, including mid fast-paste with modifiers still
        // held; hiding first clears the session so the release pastes nothing.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, event.keyCode == 53 else { return event }
            self.hide()
            return nil
        }
    }

    var isPanelVisible: Bool { panel.isVisible }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    // Hotkey presses while fast paste is enabled: open, then a quick second
    // press switches to search, later presses walk the selection.
    func handleFastKeyDown() {
        if !panel.isVisible {
            _ = tapTracker.register()
            show(fastSession: true)
        } else if viewModel.isFastSession {
            switch tapTracker.register() {
            case .enterSearch(let undoAdvance):
                if undoAdvance {
                    viewModel.moveSelection(-1)
                }
                viewModel.isFastSession = false
            case .open, .advance:
                viewModel.moveSelection(1)
            }
        } else {
            hide()
        }
    }

    func show(fastSession: Bool = false) {
        viewModel.reset()
        viewModel.isFastSession = fastSession
        centerOnActiveScreen()
        panel.orderFrontRegardless()
        panel.makeKey()
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.panelDidAppear()
        }

        if fastSession {
            // A very quick tap can release the modifiers before the panel is
            // key; in that case no flagsChanged will arrive, so check now.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.viewModel.isFastSession else { return }
                let held = NSEvent.modifierFlags.intersection([.command, .shift, .control, .option])
                if held.isEmpty {
                    self.commitFastSelection()
                }
            }
        }
    }

    func hide() {
        tapTracker.reset()
        viewModel.isFastSession = false
        panel.orderOut(nil)
    }

    private func commitFastSelection() {
        guard let item = viewModel.selectedItem else {
            hide()
            return
        }
        onCommit(item)
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
