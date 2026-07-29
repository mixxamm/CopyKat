import AppKit
import KeyboardShortcuts
import SwiftData
import os

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}

@MainActor
final class AppState {
    let historyStore: HistoryStore
    let imageStore: ImageStore
    let pasteService: PasteService
    let panelViewModel: PanelViewModel
    private(set) var panelController: PanelController?
    private var monitor: ClipboardMonitor?
    private let logger = Logger(subsystem: "dev.mixxamm.CopyCat", category: "AppState")

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CopyCat")
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            imageStore = try ImageStore(directory: appSupport.appendingPathComponent("Images"))
            pasteService = PasteService(imageStore: imageStore)
            let config = ModelConfiguration(url: appSupport.appendingPathComponent("History.store"))
            let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
            historyStore = HistoryStore(container: container, imageStore: imageStore)
        } catch {
            fatalError("CopyCat cannot open its storage: \(error)")
        }

        historyStore.maxItems = AppSettings.maxItems
        historyStore.pruneOrphans()

        // Assigned before any closure captures `self` (even weakly), since Swift
        // requires all non-optional stored properties to be initialized first.
        panelViewModel = PanelViewModel(store: historyStore)

        let monitor = ClipboardMonitor { [weak self] candidate in
            guard let self else { return }
            do {
                try self.historyStore.add(candidate)
            } catch {
                self.logger.error("Failed to store clipboard item: \(error)")
            }
        }
        monitor.start()
        self.monitor = monitor

        let controller = PanelController(
            viewModel: panelViewModel,
            imageStore: imageStore,
            onCommit: { [weak self] item in self?.commit(item) }
        )
        panelController = controller
        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController?.toggle()
        }
    }

    private func commit(_ item: ClipboardItem) {
        panelController?.hide()
        pasteService.write(item)

        if pasteService.isAccessibilityTrusted {
            // Give the key window a beat to restore focus before the keystroke arrives.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pasteService.sendPasteKeystroke()
            }
        } else if !AppSettings.hasPromptedAccessibility {
            AppSettings.hasPromptedAccessibility = true
            explainAccessibility()
        }
    }

    private func explainAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Paste directly into other apps?"
        alert.informativeText = """
        CopyCat can press ⌘V for you so a selected item is pasted immediately. \
        macOS requires the Accessibility permission for this. Without it, items are \
        only copied to the clipboard and you paste them yourself.
        """
        alert.addButton(withTitle: "Enable in System Settings")
        alert.addButton(withTitle: "Just Copy")
        if alert.runModal() == .alertFirstButtonReturn {
            pasteService.promptForAccessibility()
        }
    }
}
