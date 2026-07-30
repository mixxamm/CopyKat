import AppKit
import KeyboardShortcuts
#if !MAS
import Sparkle
#endif
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
    private let demoBackdrop = DemoBackdrop()
    let settingsWindowController = SettingsWindowController()
    // The App Store build updates through the App Store, so it ships no updater.
    #if !MAS
    let updaterController: SPUStandardUpdaterController
    #endif
    private let logger = Logger(subsystem: "com.mixxamm.copykat", category: "AppState")

    // The unit-test bundle runs hosted inside this app, so `init` executes during
    // `xcodebuild test` too. Hosted tests must never touch the real user's clipboard
    // history, so under test we use a throwaway store and skip monitoring/hotkeys.
    private static var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    // Screenshot mode: a throwaway store with a curated history, so App Store
    // captures show the app doing its job instead of whatever is on the
    // developer's clipboard.
    private static var isDemo: Bool {
        ProcessInfo.processInfo.environment["COPYKAT_DEMO"] != nil
    }

    init() {
        AppSettings.migrateLegacyDefaults()

        #if !MAS
        updaterController = SPUStandardUpdaterController(
            startingUpdater: !Self.isRunningTests,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif

        let appSupport: URL
        if Self.isRunningTests || Self.isDemo {
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

        historyStore.selfWriteTracker = pasteService.selfWriteTracker
        // Copying something new makes the remembered paste stale: the panel
        // should open on the newest item again.
        historyStore.externalCopyArrived = { AppSettings.lastPastedContentHash = nil }
        historyStore.maxItems = AppSettings.maxItems
        historyStore.migrateLegacyContentHashes()
        historyStore.backfillPinShortcutIDs()
        historyStore.pruneOrphans()

        // Assigned before any closure captures `self` (even weakly), since Swift
        // requires all non-optional stored properties to be initialized first.
        panelViewModel = PanelViewModel(store: historyStore)

        let monitor = ClipboardMonitor { [weak self] candidate in
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
            onCommit: { [weak self] item in self?.commit(item) },
            onRecordShortcut: { [weak self] _ in
                guard let self else { return }
                self.settingsWindowController.show(appState: self, tab: .pins)
            }
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

            if Self.isDemo {
                seedDemoHistory()
                demoBackdrop.show()
                let scene = ProcessInfo.processInfo.environment["COPYKAT_DEMO"] ?? "panel"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self else { return }
                    switch scene {
                    case "settings":
                        self.settingsWindowController.show(appState: self)
                        if let window = NSApp.windows.first(where: { $0.title.contains("CopyKat") }),
                           let screen = NSScreen.main {
                            let frame = window.frame
                            window.setFrameOrigin(NSPoint(
                                x: screen.frame.midX - frame.width / 2,
                                y: screen.frame.midY - frame.height / 2 - 30
                            ))
                        }
                    case "search":
                        self.panelController?.show()
                        self.panelViewModel.query = ProcessInfo.processInfo.environment["COPYKAT_DEMO_QUERY"] ?? "interfce"
                    default:
                        self.panelController?.show()
                        self.panelViewModel.moveSelection(3)
                    }
                }
            } else if !AppSettings.hasCompletedOnboarding {
                onboardingController.show(appState: self)
            }

        }
    }

    private func seedDemoHistory() {
        // Oldest first: consecutive items from one app end up grouped under a
        // single header in the panel, which is what the screenshots should show.
        let demo: [(String, String, String)] = [
            ("com.apple.mail", "Mail", "maxim@copykat.dev"),
            ("com.apple.Safari", "Safari", "https://swiftpackageindex.com/pointfreeco/swift-snapshot-testing"),
            ("com.apple.Safari", "Safari", "https://developer.apple.com/design/human-interface-guidelines"),
            ("com.apple.Terminal", "Terminal", "git rebase -i origin/main"),
            ("com.apple.Terminal", "Terminal", "docker compose up -d"),
            ("com.apple.Notes", "Notes", "Standup: ship the release notes, then the changelog"),
            ("com.apple.Notes", "Notes", "IBAN BE31 6792 0034 9355"),
            ("com.apple.finder", "Finder", "Q3-invoice.pdf"),
        ]
        for (bundleID, name, text) in demo {
            try? historyStore.add(ClipboardCandidate(
                content: .text(text), sourceAppBundleID: bundleID, sourceAppName: name
            ))
        }
        panelViewModel.refresh()
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
