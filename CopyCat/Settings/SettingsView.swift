import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    let appState: AppState

    @State private var maxItems = AppSettings.maxItems
    @State private var excludedBundleIDs = AppSettings.excludedBundleIDs
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var selectedExclusion: String?

    var body: some View {
        Form {
            Section("General") {
                KeyboardShortcuts.Recorder("Open panel", name: .togglePanel)

                Stepper(value: $maxItems, in: 10...1000, step: 10) {
                    Text("Keep \(maxItems) items")
                }
                .onChange(of: maxItems) { _, value in
                    AppSettings.maxItems = value
                    appState.historyStore.maxItems = value
                }

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
        .frame(width: 440)
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
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All items except pinned ones are removed. This cannot be undone."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            appState.historyStore.deleteAll()
        }
    }
}
