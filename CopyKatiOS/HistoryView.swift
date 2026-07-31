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
            .background(backdrop)
            .navigationTitle("CopyKat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandMark()
                }
            }
            .searchable(text: $query, prompt: Text("Search clipboard history"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            // Free-floating, not in the bottom toolbar: the toolbar wraps its
            // items in glass, and a glass shell around a solid system control
            // reads as neither one thing nor the other.
            .safeAreaInset(edge: .bottom) {
                PasteButton(payloadType: CapturedPayload.self) { payloads in
                    Task { @MainActor in
                        for payload in payloads {
                            model.capture(payload.content)
                        }
                        refresh()
                    }
                }
                .buttonBorderShape(.capsule)
                .padding(.bottom, 6)
            }
            .sheet(isPresented: $showingSettings) {
                PhoneSettingsView(model: model)
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: query) { _, _ in refresh() }
    }

    // systemGroupedBackground with a breath of the brand falling in from the
    // top. Strong enough to register as CopyKat, weak enough to keep every
    // contrast ratio where the grouped palette put it.
    private var backdrop: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color.brand.opacity(0.16), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Nothing here yet")
            } icon: {
                Image(systemName: "cat.fill")
                    .foregroundStyle(LinearGradient.brand)
            }
        } description: {
            Text("Copy something and tap Paste below, or share it to CopyKat from any app.")
        }
    }

    // Cards, not rows: clipboard items are glanceable blobs, and a grid shows
    // twice as many of them per screen.
    private var list: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    Button {
                        model.copyToClipboard(item)
                        AppSettings.lastPastedContentHash = item.contentHash
                        flashCopied(item)
                    } label: {
                        PhoneItemCard(
                            item: item,
                            imageStore: model.imageStore,
                            showsCopied: copiedID == item.persistentModelID
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            model.historyStore.togglePin(item)
                            refresh()
                        } label: {
                            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                        }
                        Button(role: .destructive) {
                            model.historyStore.deleteUndoably(item)
                            refresh()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        // The app-wide brand tint would paint the trash icon
                        // orange while the destructive role reds the text;
                        // destructive means red through and through.
                        .tint(.red)
                    }
                }
            }
            .padding(12)
        }
        .refreshable {
            await model.refreshFromCloud()
            refresh()
        }
    }

    private func refresh() {
        items = model.historyStore.items(matching: query)
        if query.isEmpty {
            model.refreshKeyboardSnapshot()
        }
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

struct PhoneItemCard: View {
    let item: ClipboardItem
    let imageStore: ImageStore
    var showsCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            footer
        }
        .frame(height: 150)
        .background(
            item.isPinned ? Color.brand.opacity(0.10) : Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        // The card's rounding must also clip its content: a full-bleed image
        // would otherwise poke square corners out of a rounded card.
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if showsCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, Color.brand)
                    .font(.title3)
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Text("Copied"))
            }
        }
        .animation(.snappy(duration: 0.2), value: showsCopied)
        .accessibilityElement(children: .combine)
    }

    // Short snippets get display type, paragraphs get reading type: a card
    // holding "4589" should not whisper it in fine print.
    private func textFont(for text: String) -> Font {
        switch text.count {
        case ..<25: .title2.weight(.medium)
        case ..<80: .callout
        default: .footnote
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "")
                .font(textFont(for: item.text ?? ""))
                .lineLimit(6)
                .padding(10)
        case .fileURL:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
                Text((item.text as NSString?)?.lastPathComponent ?? "")
                    .font(.footnote)
                    .lineLimit(3)
            }
            .padding(10)
        case .image:
            if let filename = item.imageFilename,
               let thumb = imageStore.thumbnail(for: filename, maxDimension: 240) {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 5) {
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            // Where it came from: the recording app's name travels along with
            // the sync, and the laptop marks anything that arrived from a Mac.
            if item.isRemote {
                Image(systemName: "macbook")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let source = item.sourceAppName, !source.isEmpty {
                Text(verbatim: source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Text(item.createdAt, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial)
    }
}
