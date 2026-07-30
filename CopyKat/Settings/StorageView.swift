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
    @State private var lastDeleted: Int?

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

                    HStack {
                        Button("Delete Older Items", role: .destructive, action: deleteOlder)
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

    private func deleteOlder() {
        lastDeleted = appState.historyStore.deleteItems(olderThan: age.cutoff)
        usage = appState.historyStore.storageUsage()
    }

    private func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
