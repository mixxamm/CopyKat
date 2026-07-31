import SwiftUI

struct PhoneSettingsView: View {
    @Environment(\.dismiss) private var dismiss

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
