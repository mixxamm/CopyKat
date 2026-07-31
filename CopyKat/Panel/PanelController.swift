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
    private var commandMonitor: Any?
    private var vimMonitor: Any?

    init(
        viewModel: PanelViewModel,
        imageStore: ImageStore,
        onCommit: @escaping (ClipboardItem) -> Void,
        onRecordShortcut: @escaping (ClipboardItem) -> Void
    ) {
        self.viewModel = viewModel
        self.onCommit = onCommit
        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: PanelSize.full))
        super.init()

        let view = PanelView(
            model: viewModel,
            imageStore: imageStore,
            onCommit: onCommit,
            onDismiss: { [weak self] in self?.hide() },
            onRecordShortcut: { [weak self] item in
                self?.hide()
                onRecordShortcut(item)
            },
            onResize: { [weak self] size in self?.resize(to: size) }
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

        // hjkl has to be caught before the search field turns it into text, so
        // it lives in a monitor rather than in the view.
        vimMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, self.viewModel.vimNavigationIsActive,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            else { return event }

            switch event.charactersIgnoringModifiers?.lowercased() {
            case "j", "l":
                self.viewModel.moveSelection(1)
                return nil
            case "k", "h":
                self.viewModel.moveSelection(-1)
                return nil
            default:
                return event
            }
        }

        // Every ⌘ shortcut in the panel, in one place. Shift is optional for all
        // of them: the hotkey that opens the panel holds it down and people
        // reach for these without letting go. SwiftUI cannot do this, because it
        // reports the shifted character, so ⌘⇧1 arrives as "!" rather than "1";
        // asking NSEvent for the keystroke with no modifiers applied is both
        // shift-proof and correct on layouts where digits need shift anyway.
        commandMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible,
                  event.modifierFlags.contains(.command),
                  let key = event.characters(byApplyingModifiers: [])?.lowercased()
            else { return event }

            switch key {
            case "d":
                self.viewModel.deleteSelected()
                return nil
            case "u":
                self.viewModel.undoDelete()
                return nil
            case "p":
                self.viewModel.togglePinSelected()
                return nil
            default:
                break
            }

            guard let digit = key.first?.wholeNumberValue,
                  let item = self.viewModel.quickPasteItem(at: digit)
            else { return event }
            self.onCommit(item)
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
                // With the search field hidden there is nothing to switch to,
                // so a quick second press is just another step through history.
                guard viewModel.searchIsVisible else {
                    viewModel.moveSelection(1)
                    break
                }
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
        panel.setFrame(
            NSRect(
                origin: panel.frame.origin,
                size: PanelSize.current(
                    listIsVisible: viewModel.listIsVisible,
                    searchIsVisible: viewModel.searchIsVisible
                )
            ),
            display: false
        )
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

    // Typing brings the list back mid-session. Growing from a fixed top edge
    // keeps the search field under the cursor instead of sliding it upwards.
    private func resize(to size: CGSize) {
        guard panel.frame.size != size else { return }
        let frame = panel.frame
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
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
