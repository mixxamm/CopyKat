import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    let model: PhoneAppModel

    @State private var query = ""
    @State private var items: [ClipboardItem] = []
    @State private var copiedID: PersistentIdentifier?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty && query.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("CopyKat")
            .searchable(text: $query, prompt: Text("Search clipboard history"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    // Apple's paste control: capturing the clipboard is one tap
                    // and never shows the paste alert.
                    PasteButton(payloadType: CapturedPayload.self) { payloads in
                        Task { @MainActor in
                            for payload in payloads {
                                model.capture(payload.content)
                            }
                            refresh()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                }
            }
            .sheet(isPresented: $showingSettings) {
                PhoneSettingsView()
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: query) { _, _ in refresh() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing here yet",
            systemImage: "doc.on.clipboard",
            description: Text("Copy something and tap Paste below, or share it to CopyKat from any app.")
        )
    }

    private var list: some View {
        List {
            ForEach(items) { item in
                Button {
                    model.copyToClipboard(item)
                    AppSettings.lastPastedContentHash = item.contentHash
                    flashCopied(item)
                } label: {
                    PhoneItemRow(
                        item: item,
                        imageStore: model.imageStore,
                        showsCopied: copiedID == item.persistentModelID
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        model.historyStore.togglePin(item)
                        refresh()
                    } label: {
                        Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        model.historyStore.deleteUndoably(item)
                        refresh()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func refresh() {
        items = model.historyStore.items(matching: query)
    }

    // A brief checkmark on the row beats a toast: it stays exactly where the
    // finger already is.
    private func flashCopied(_ item: ClipboardItem) {
        copiedID = item.persistentModelID
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedID == item.persistentModelID {
                copiedID = nil
            }
        }
    }
}

// What the paste button accepts: a string or an image, whichever the clipboard
// holds. Order matters; the runtime picks the first representation that loads.
struct CapturedPayload: Transferable {
    let content: ClipboardCandidate.Content

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .png) { data in
            CapturedPayload(content: .image(data))
        }
        DataRepresentation(importedContentType: .image) { data in
            // Whatever arrived (JPEG, HEIC), the store keeps PNG.
            guard let image = UIImage(data: data), let png = image.pngData() else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return CapturedPayload(content: .image(png))
        }
        ProxyRepresentation { (text: String) in
            CapturedPayload(content: .text(text))
        }
    }
}

struct PhoneItemRow: View {
    let item: ClipboardItem
    let imageStore: ImageStore
    var showsCopied = false

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                content
                subtitle
            }
            Spacer(minLength: 0)
            if showsCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Text("Copied"))
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .animation(.snappy(duration: 0.2), value: showsCopied)
    }

    @ViewBuilder
    private var leading: some View {
        if item.kind == .image, let filename = item.imageFilename,
           let thumb = imageStore.thumbnail(for: filename, maxDimension: 44) {
            Image(uiImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: item.kind == .fileURL ? "doc" : (item.isRemote ? "macbook" : "text.alignleft"))
                .frame(width: 44, height: 44)
                .foregroundStyle(.secondary)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "").lineLimit(2)
        case .fileURL:
            Text((item.text as NSString?)?.lastPathComponent ?? "").lineLimit(1)
        case .image:
            Text(item.recognizedText?.split(whereSeparator: \.isNewline).first.map(String.init) ?? String(localized: "Image"))
                .lineLimit(1)
                .foregroundStyle(item.recognizedText == nil ? .secondary : .primary)
        }
    }

    private var subtitle: some View {
        Text(item.createdAt, format: .relative(presentation: .named))
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}
