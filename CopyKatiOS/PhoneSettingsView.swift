import SwiftUI

struct PhoneSettingsView: View {
    let model: PhoneAppModel
    @Environment(\.dismiss) private var dismiss

    @State private var syncEnabled = AppSettings.cloudSyncEnabled
    @State private var syncText = AppSettings.cloudSyncText
    @State private var syncFiles = AppSettings.cloudSyncFiles
    @State private var syncImages = AppSettings.cloudSyncImages
    @State private var syncScope = AppSettings.cloudSyncScope

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Enabling a keyboard only works from Settings; the app's
                    // own Settings page carries the Keyboards entry because we
                    // bundle one, so the deep link lands exactly right.
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Enable the CopyKat keyboard", systemImage: "keyboard")
                    }
                } footer: {
                    Text("Turn on CopyKat under Keyboards to paste from your history wherever you type. It works without Full Access.")
                }

                Section {
                    Toggle("Sync with iCloud", isOn: $syncEnabled)
                        .onChange(of: syncEnabled) { _, value in
                            AppSettings.cloudSyncEnabled = value
                            model.cloudSyncSettingsChanged()
                        }
                    Group {
                        Toggle("Text", isOn: $syncText)
                            .onChange(of: syncText) { _, value in
                                AppSettings.cloudSyncText = value
                                model.cloudSyncSettingsChanged()
                            }
                        Toggle("Files", isOn: $syncFiles)
                            .onChange(of: syncFiles) { _, value in
                                AppSettings.cloudSyncFiles = value
                                model.cloudSyncSettingsChanged()
                            }
                        Toggle("Images", isOn: $syncImages)
                            .onChange(of: syncImages) { _, value in
                                AppSettings.cloudSyncImages = value
                                model.cloudSyncSettingsChanged()
                            }
                        Picker("What syncs", selection: $syncScope) {
                            Text("Everything").tag("everything")
                            Text("Pinned only").tag("pinned")
                            Text("Recent and pinned").tag("recent")
                        }
                        .onChange(of: syncScope) { _, value in
                            AppSettings.cloudSyncScope = value
                            model.cloudSyncSettingsChanged()
                        }
                    }
                    .disabled(!syncEnabled)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Carries your history through your own iCloud. Nothing ever touches our servers, and nothing syncs until you turn this on. Images are what costs real iCloud space.")
                }

                Section {
                    LabeledContent("Version") {
                        Text(verbatim: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                    }
                } footer: {
                    Text("Your Mac records the clipboard; this app carries it. Everything stays on your devices.")
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
