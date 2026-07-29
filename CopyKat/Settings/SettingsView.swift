import SwiftUI
import KeyboardShortcuts
import ServiceManagement

enum SettingsTab: String {
    case general
    case pins
}

struct SettingsView: View {
    let appState: AppState

    @AppStorage(AppSettings.selectedSettingsTabKey) private var selectedTab = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(appState: appState)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general.rawValue)
            PinsSettingsView(appState: appState)
                .tabItem { Label("Pins", systemImage: "pin") }
                .tag(SettingsTab.pins.rawValue)
        }
        .frame(width: 440)
    }
}

private struct GeneralSettingsView: View {
    let appState: AppState

    @State private var maxItems = AppSettings.maxItems
    @State private var excludedBundleIDs = AppSettings.excludedBundleIDs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var selectedExclusion: String?
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon = AppSettings.defaultMenuBarIcon

    var body: some View {
        Form {
            Section("General") {
                KeyboardShortcuts.Recorder("Open panel", name: .togglePanel)

                Picker("Menu bar icon", selection: $menuBarIcon) {
                    ForEach(AppSettings.menuBarIconOptions, id: \.self) { name in
                        Image(systemName: name).tag(name)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $maxItems, in: 10...1000, step: 10) {
                    Text("Keep \(maxItems) items")
                }
                .onChange(of: maxItems) { _, value in
                    AppSettings.maxItems = value
                    appState.historyStore.maxItems = value
                }

                Toggle("Automatically check for updates", isOn: Binding(
                    get: { appState.updaterController.updater.automaticallyChecksForUpdates },
                    set: { appState.updaterController.updater.automaticallyChecksForUpdates = $0 }
                ))

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Ignored apps") {
                Text("Clipboard changes from these apps are never recorded. Password managers that mark entries as concealed are ignored automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                List(excludedBundleIDs, id: \.self, selection: $selectedExclusion) { bundleID in
                    HStack {
                        if let icon = AppIconProvider.icon(forBundleID: bundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text(bundleID)
                    }
                }
                .frame(minHeight: 120)

                HStack {
                    Button("Add App…", action: addApp)
                    Button("Remove") {
                        excludedBundleIDs.removeAll { $0 == selectedExclusion }
                        AppSettings.excludedBundleIDs = excludedBundleIDs
                        selectedExclusion = nil
                    }
                    .disabled(selectedExclusion == nil)
                }
            }

            Section {
                Button("Clear History…", role: .destructive) {
                    confirmClearHistory()
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier,
              !excludedBundleIDs.contains(bundleID)
        else { return }
        excludedBundleIDs.append(bundleID)
        AppSettings.excludedBundleIDs = excludedBundleIDs
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear clipboard history?")
        alert.informativeText = String(localized: "All items except pinned ones are removed. This cannot be undone.")
        alert.addButton(withTitle: String(localized: "Clear History"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            appState.historyStore.deleteAll()
        }
    }
}

private struct PinsSettingsView: View {
    let appState: AppState

    @State private var pinnedItems: [ClipboardItem] = []

    var body: some View {
        Form {
            if pinnedItems.isEmpty {
                Text("No pinned items yet. Pin an item in the panel with ⌘P (or right-click it), then give it a shortcut here to paste it from anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Section("Paste shortcuts") {
                    ForEach(pinnedItems, id: \.persistentModelID) { item in
                        HStack(spacing: 10) {
                            rowIcon(for: item)
                            Text(rowTitle(for: item))
                                .lineLimit(1)
                            Spacer()
                            if let id = item.pinShortcutID {
                                KeyboardShortcuts.Recorder("", name: PinShortcutManager.shortcutName(for: id))
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { pinnedItems = appState.historyStore.pinnedItems() }
    }

    @ViewBuilder
    private func rowIcon(for item: ClipboardItem) -> some View {
        if item.kind == .image, let filename = item.imageFilename,
           let thumb = appState.imageStore.thumbnail(for: filename, maxDimension: 24) {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: item.kind == .fileURL ? "doc" : "text.alignleft")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        }
    }

    private func rowTitle(for item: ClipboardItem) -> String {
        switch item.kind {
        case .text:
            return item.text ?? ""
        case .fileURL:
            return (item.text as NSString?)?.lastPathComponent ?? ""
        case .image:
            if let width = item.imageWidth, let height = item.imageHeight {
                return "Image (\(width) × \(height))"
            }
            return "Image"
        }
    }
}
