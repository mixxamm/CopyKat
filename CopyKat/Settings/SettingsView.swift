import SwiftUI
import KeyboardShortcuts
import ServiceManagement

enum SettingsTab: String {
    case general
    case pins
}

// Two tabs for a handful of controls is more chrome than content, and SwiftUI's
// tab strip sits on a grey band that reads as unfinished inside our own window.
// One scrolling pane of grouped sections is calmer and more Mac-like.
struct SettingsView: View {
    let appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeneralSettingsView(appState: appState)
                PinsSettingsView(appState: appState)
            }
        }
        .frame(width: 480, height: 560)
    }
}

private struct GeneralSettingsView: View {
    let appState: AppState

    @State private var maxItems = AppSettings.maxItems
    @State private var unlimitedHistory = AppSettings.unlimitedHistory
    @State private var usedBytes: Int64 = 0
    @State private var showingStorage = false
    @State private var excludedBundleIDs = AppSettings.excludedBundleIDs
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var cloudSyncEnabled = AppSettings.cloudSyncEnabled
    @State private var cloudSyncText = AppSettings.cloudSyncText
    @State private var cloudSyncFiles = AppSettings.cloudSyncFiles
    @State private var cloudSyncImages = AppSettings.cloudSyncImages
    @State private var cloudSyncScope = AppSettings.cloudSyncScope
    @State private var selectedExclusion: String?
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon = AppSettings.defaultMenuBarIcon

    var body: some View {
        Form {
            Section("Panel") {
                KeyboardShortcuts.Recorder("Open panel", name: .togglePanel)

                Picker("Menu bar icon", selection: $menuBarIcon) {
                    ForEach(AppSettings.menuBarIconOptions, id: \.self) { name in
                        Image(systemName: name).tag(name)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Animate scrolling", isOn: Binding(
                    get: { AppSettings.animateScrolling },
                    set: { AppSettings.animateScrolling = $0 }
                ))

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Hide the list", isOn: Binding(
                        get: { AppSettings.hideListUntilSearch },
                        set: { AppSettings.hideListUntilSearch = $0 }
                    ))
                    Text("Opens a smaller panel showing only the highlighted item. Arrow keys still walk the history, and the list comes back as soon as you type.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Vim navigation", isOn: Binding(
                        get: { AppSettings.vimNavigation },
                        set: { AppSettings.vimNavigation = $0 }
                    ))
                    Text("Adds h, j, k and l alongside the arrow keys. They only move the highlight while the search field is empty, so searching stays possible.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Hide the search field", isOn: Binding(
                        get: { AppSettings.hideSearchBar },
                        set: { AppSettings.hideSearchBar = $0 }
                    ))
                    Text("Leaves out the search field entirely, for cycling with the keyboard alone. Double-tapping V then keeps stepping through the history instead of starting a search.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Fast paste", isOn: Binding(
                        get: { AppSettings.fastPasteEnabled },
                        set: { AppSettings.fastPasteEnabled = $0 }
                    ))
                    Text("Hold the shortcut and let go to paste the highlighted item right away. Double-tap V to search instead.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

            }

            Section("History") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Search inside images", isOn: Binding(
                        get: { AppSettings.indexImageContent },
                        set: { AppSettings.indexImageContent = $0 }
                    ))
                    Text("Reads text, QR codes and subjects out of copied images, entirely on this Mac, so search can find them. ⌥↩ pastes the recognized text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Toggle("Keep everything", isOn: $unlimitedHistory)
                    .onChange(of: unlimitedHistory) { _, value in
                        AppSettings.unlimitedHistory = value
                        appState.historyStore.maxItems = AppSettings.historyLimit
                    }

                Stepper(value: $maxItems, in: 10...1000, step: 10) {
                    Text("Keep \(maxItems) items")
                }
                .onChange(of: maxItems) { _, value in
                    AppSettings.maxItems = value
                    appState.historyStore.maxItems = AppSettings.historyLimit
                }
                .disabled(unlimitedHistory)

                LabeledContent("On disk") {
                    HStack(spacing: 10) {
                        Text(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))
                            .foregroundStyle(.secondary)
                        Button("Manage…") { showingStorage = true }
                    }
                }

                Button("Clear History…", role: .destructive) {
                    confirmClearHistory()
                }
            }

            Section("Startup") {
                #if !MAS
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { appState.updaterController.updater.automaticallyChecksForUpdates },
                    set: { appState.updaterController.updater.automaticallyChecksForUpdates = $0 }
                ))
                #endif

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        let actual = LoginItem.setEnabled(enabled)
                        if actual != enabled { launchAtLogin = actual }
                    }
            }

            Section("Sync") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Sync with iCloud", isOn: $cloudSyncEnabled)
                        .onChange(of: cloudSyncEnabled) { _, value in
                            AppSettings.cloudSyncEnabled = value
                            appState.cloudSyncSettingsChanged()
                        }
                    Text("Carries your history to your other devices through your own iCloud. Nothing ever touches our servers, and nothing syncs until you turn this on.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Group {
                    Toggle("Text", isOn: $cloudSyncText)
                        .onChange(of: cloudSyncText) { _, value in
                            AppSettings.cloudSyncText = value
                            appState.cloudSyncSettingsChanged()
                        }
                    Toggle("Files", isOn: $cloudSyncFiles)
                        .onChange(of: cloudSyncFiles) { _, value in
                            AppSettings.cloudSyncFiles = value
                            appState.cloudSyncSettingsChanged()
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Images", isOn: $cloudSyncImages)
                            .onChange(of: cloudSyncImages) { _, value in
                                AppSettings.cloudSyncImages = value
                                appState.cloudSyncSettingsChanged()
                            }
                        Text("Images are what costs real iCloud space.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Picker("What syncs", selection: $cloudSyncScope) {
                        Text("Everything").tag("everything")
                        Text("Pinned only").tag("pinned")
                        Text("Recent and pinned").tag("recent")
                    }
                    .onChange(of: cloudSyncScope) { _, value in
                        AppSettings.cloudSyncScope = value
                        appState.cloudSyncSettingsChanged()
                    }

                    if let sync = appState.cloudSync {
                        if let error = sync.lastError {
                            Label {
                                Text(verbatim: error)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                            }
                            .font(.callout)
                        } else {
                            Text("\(sync.syncedCount) items in iCloud")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!cloudSyncEnabled)
            }

            Section("Ignored apps") {
                Text("Clipboard changes from these apps are never recorded. Common password managers, including Apple Passwords, are already excluded by default.")
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
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { usedBytes = appState.historyStore.storageUsage().totalBytes }
        .sheet(isPresented: $showingStorage, onDismiss: {
            usedBytes = appState.historyStore.storageUsage().totalBytes
        }) {
            StorageView(appState: appState)
        }
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
            Section("Pinned items") {
                if pinnedItems.isEmpty {
                    Text("No pinned items yet. Pin an item in the panel with ⌘P (or right-click it), then give it a shortcut here to paste it from anywhere.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
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
        .scrollDisabled(true)
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
                return String(localized: "Image (\(width) × \(height))")
            }
            return String(localized: "Image")
        }
    }
}
