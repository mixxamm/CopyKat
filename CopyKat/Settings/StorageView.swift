import AppKit
import SwiftUI

enum HistoryAge: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case threeMonths = 90
    case sixMonths = 180
    case year = 365

    var id: Int { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .week: "1 week"
        case .month: "1 month"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        case .year: "1 year"
        }
    }

    var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -rawValue, to: .now) ?? .now
    }
}

struct StorageView: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var usage = HistoryStore.StorageUsage()
    @State private var age: HistoryAge = .month
    @State private var scope: CleanupScope = .imagesOnly
    @State private var lastDeleted: Int?

    enum CleanupScope: Hashable, CaseIterable, Identifiable {
        case imagesOnly
        case everything

        var id: Self { self }

        var label: LocalizedStringKey {
            switch self {
            case .imagesOnly: "Images only"
            case .everything: "Everything"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("What your history uses") {
                    LabeledContent("Images", value: "\(usage.imageItems) items, \(bytes(usage.imageBytes))")
                    LabeledContent("Text and files", value: "\(usage.textItems) items")
                    LabeledContent("Database", value: bytes(usage.databaseBytes))
                    LabeledContent("Total", value: bytes(usage.totalBytes))
                        .fontWeight(.semibold)
                }

                Section("Clean up") {
                    Picker("Delete items older than", selection: $age) {
                        ForEach(HistoryAge.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Picker("What to delete", selection: $scope) {
                        ForEach(CleanupScope.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button("Delete Older Items", role: .destructive, action: confirmDeleteOlder)
                        if let lastDeleted {
                            Text(lastDeleted == 1 ? "1 item removed" : "\(lastDeleted) items removed")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Pinned items are always kept, however old they are.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460, height: 470)
        .onAppear { usage = appState.historyStore.storageUsage() }
    }

    // A sweep can take out hundreds of items at once and, unlike deleting a
    // single row in the panel, there is no undo for it.
    private func confirmDeleteOlder() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Delete older items?")
        alert.informativeText = scope == .imagesOnly
            ? String(localized: "Images older than the chosen age are removed. Text is left alone, pinned items are always kept, and this cannot be undone.")
            : String(localized: "Everything older than the chosen age is removed, except pinned items. This cannot be undone.")
        alert.addButton(withTitle: String(localized: "Delete Older Items"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        deleteOlder()
    }

    private func deleteOlder() {
        lastDeleted = appState.historyStore.deleteItems(
            olderThan: age.cutoff,
            imagesOnly: scope == .imagesOnly
        )
        usage = appState.historyStore.storageUsage()
    }

    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
