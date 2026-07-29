import AppKit
import KeyboardShortcuts
import Sparkle
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
    private var pinShortcutManager: PinShortcutManager?
    let onboardingController = OnboardingController()
    let updaterController: SPUStandardUpdaterController
    private let logger = Logger(subsystem: "dev.mixxamm.CopyKat", category: "AppState")

    // The unit-test bundle runs hosted inside this app, so `init` executes during
    // `xcodebuild test` too. Hosted tests must never touch the real user's clipboard
    // history, so under test we use a throwaway store and skip monitoring/hotkeys.
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: !Self.isRunningTests,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let appSupport: URL
        if Self.isRunningTests {
            appSupport = FileManager.default.temporaryDirectory
                .appendingPathComponent("CopyKatTests-\(UUID().uuidString)")
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            appSupport = root.appendingPathComponent("CopyKat")
            // The app was briefly called CopyCat and then KopyKat; adopt that
            // history on first launch.
            for legacyName in ["KopyKat", "CopyCat"] {
                let legacy = root.appendingPathComponent(legacyName)
                if !FileManager.default.fileExists(atPath: appSupport.path),
                   FileManager.default.fileExists(atPath: legacy.path) {
                    try? FileManager.default.moveItem(at: legacy, to: appSupport)
                }
            }
        }
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            imageStore = try ImageStore(directory: appSupport.appendingPathComponent("Images"))
            pasteService = PasteService(imageStore: imageStore)
            let config = ModelConfiguration(url: appSupport.appendingPathComponent("History.store"))
            let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
            historyStore = HistoryStore(container: container, imageStore: imageStore)
        } catch {
            fatalError("CopyKat cannot open its storage: \(error)")
        }

        historyStore.maxItems = AppSettings.maxItems
        historyStore.migrateLegacyContentHashes()
        historyStore.backfillPinShortcutIDs()
        historyStore.pruneOrphans()

        // Assigned before any closure captures `self` (even weakly), since Swift
        // requires all non-optional stored properties to be initialized first.
        panelViewModel = PanelViewModel(store: historyStore)

        let monitor = ClipboardMonitor(selfWriteTracker: pasteService.selfWriteTracker) { [weak self] candidate in
            guard let self else { return }
            do {
                try self.historyStore.add(candidate)
                if self.panelController?.isPanelVisible == true {
                    self.panelViewModel.refresh()
                }
            } catch {
                self.logger.error("Failed to store clipboard item: \(error)")
            }
        }
        if !Self.isRunningTests {
            monitor.start()
        }
        self.monitor = monitor

        let controller = PanelController(
            viewModel: panelViewModel,
            imageStore: imageStore,
            onCommit: { [weak self] item in self?.commit(item) }
        )
        panelController = controller
        if !Self.isRunningTests {
            KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
                guard let self else { return }
                if AppSettings.fastPasteEnabled {
                    self.panelController?.handleFastKeyDown()
                } else {
                    self.panelController?.toggle()
                }
            }

            let manager = PinShortcutManager(
                pinnedItems: { [weak self] in self?.historyStore.pinnedItems() ?? [] },
                paste: { [weak self] item in self?.paste(item) }
            )
            pinShortcutManager = manager
            historyStore.pinsChanged = { [weak self] in self?.pinShortcutManager?.sync() }
            manager.sync()

            if !AppSettings.hasCompletedOnboarding {
                onboardingController.show(appState: self)
            }
        }
    }

    private func commit(_ item: ClipboardItem) {
        panelController?.hide()
        paste(item)
    }

    private func paste(_ item: ClipboardItem) {
        guard pasteService.write(item) else { return }
        AppSettings.lastPastedContentHash = item.contentHash

        if pasteService.isAccessibilityTrusted {
            // Give the key window a beat to restore focus before the keystroke arrives.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.pasteService.sendPasteKeystroke()
            }
        } else if !AppSettings.accessibilityDeclined {
            // Keep explaining on every paste attempt until the permission is
            // granted; a silent copy-only fallback looks like a paste bug. Only
            // an explicit "Just Copy" silences it.
            explainAccessibility()
        }
    }

    private func explainAccessibility() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Paste directly into other apps?")
        alert.informativeText = String(localized: """
        CopyKat can press ⌘V for you so a selected item is pasted immediately. \
        macOS requires the Accessibility permission for this. Without it, items are \
        only copied to the clipboard and you paste them yourself.
        """)
        alert.addButton(withTitle: String(localized: "Enable in System Settings"))
        alert.addButton(withTitle: String(localized: "Just Copy"))
        if alert.runModal() == .alertFirstButtonReturn {
            pasteService.promptForAccessibility()
            pasteService.openAccessibilitySettings()
        } else {
            AppSettings.accessibilityDeclined = true
        }
    }
}
