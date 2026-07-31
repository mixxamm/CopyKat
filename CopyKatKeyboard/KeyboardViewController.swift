import SwiftUI
import UIKit

// The keyboard is a picker, not a typing surface: the history as a list, tap
// to insert, globe to get Apple's keyboard back. It runs without Full Access;
// text inserts through the document proxy. Images can only travel via the
// pasteboard, so they appear once the user grants Full Access and tapping one
// copies it ready to paste.
final class KeyboardViewController: UIInputViewController {
    private var snapshot = KeyboardSnapshot()
    private var imageStore: ImageStore?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let container = AppGroup.container {
            snapshot = KeyboardSnapshot.read(from: container)
            imageStore = try? ImageStore(
                directory: container
                    .appendingPathComponent("CopyKat", isDirectory: true)
                    .appendingPathComponent("Images")
            )
        }

        let root = KeyboardView(
            entries: sortedEntries,
            imagesAllowed: hasFullAccess,
            needsGlobe: needsInputModeSwitchKey,
            thumbnail: { [weak self] filename in
                self?.imageStore?.thumbnail(for: filename, maxDimension: 72)
            },
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onCopyImage: { [weak self] filename in
                self?.copyImageToPasteboard(named: filename) ?? false
            },
            onDelete: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            globe: { [weak self] in self?.makeGlobeButton() }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            view.heightAnchor.constraint(equalToConstant: 260),
        ])
        host.didMove(toParent: self)
    }

    private var sortedEntries: [KeyboardSnapshot.Entry] {
        snapshot.entries.filter(\.isPinned) + snapshot.entries.filter { !$0.isPinned }
    }

    private func copyImageToPasteboard(named filename: String) -> Bool {
        guard hasFullAccess, let imageStore,
              let data = try? Data(contentsOf: imageStore.imageURL(for: filename)),
              let image = UIImage(data: data)
        else { return false }
        UIPasteboard.general.image = image
        return true
    }

    // Apple requires a reachable way to switch keyboards; the system-provided
    // handler needs a UIKit control, so SwiftUI wraps this button.
    private func makeGlobeButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        button.accessibilityLabel = String(localized: "Next keyboard")
        return button
    }
}

private struct KeyboardView: View {
    let entries: [KeyboardSnapshot.Entry]
    let imagesAllowed: Bool
    let needsGlobe: Bool
    let thumbnail: (String) -> PlatformImage?
    let onInsert: (String) -> Void
    let onCopyImage: (String) -> Bool
    let onDelete: () -> Void
    let globe: () -> UIButton?

    @State private var copiedHash: String?

    // Without Full Access the pasteboard is out of reach, so image entries
    // stay hidden rather than shown broken.
    private var visible: [KeyboardSnapshot.Entry] {
        imagesAllowed ? entries : entries.filter { $0.imageFilename == nil }
    }

    private var hiddenImageCount: Int {
        imagesAllowed ? 0 : entries.filter { $0.imageFilename != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if visible.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(visible) { entry in
                            row(for: entry)
                        }
                        if hiddenImageCount > 0 {
                            Text("Allow Full Access to paste images from the keyboard.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }
                    }
                    .padding(8)
                }
            }
            bottomBar
        }
        .background(Color(.systemGroupedBackground).opacity(0.01))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
            Text("Open CopyKat once to fill this list.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func row(for entry: KeyboardSnapshot.Entry) -> some View {
        if let filename = entry.imageFilename {
            imageRow(for: entry, filename: filename)
        } else {
            textRow(for: entry)
        }
    }

    private func textRow(for entry: KeyboardSnapshot.Entry) -> some View {
        Button {
            onInsert(entry.text)
        } label: {
            HStack(spacing: 8) {
                pin(entry)
                Text(entry.text)
                    .lineLimit(2)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(entry.text))
        .accessibilityHint(Text("Inserts this text"))
    }

    // Tapping an image cannot insert it; it lands on the clipboard, and the
    // row says so while the checkmark shows.
    private func imageRow(for entry: KeyboardSnapshot.Entry, filename: String) -> some View {
        Button {
            if onCopyImage(filename) {
                copiedHash = entry.contentHash
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if copiedHash == entry.contentHash { copiedHash = nil }
                }
            }
        } label: {
            HStack(spacing: 8) {
                pin(entry)
                if let thumb = thumbnail(filename) {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if copiedHash == entry.contentHash {
                    Text("On the clipboard. Press and hold a text field, then Paste.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(entry.text.isEmpty ? String(localized: "Image") : entry.text)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundStyle(entry.text.isEmpty ? .secondary : .primary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(entry.text.isEmpty ? String(localized: "Image") : entry.text))
        .accessibilityHint(Text("Copies this image to the clipboard"))
    }

    @ViewBuilder
    private func pin(_ entry: KeyboardSnapshot.Entry) -> some View {
        if entry.isPinned {
            Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
    }

    private var bottomBar: some View {
        HStack {
            if needsGlobe, let button = globe() {
                UIKitButton(button: button)
                    .frame(width: 44, height: 36)
            }
            Spacer()
            Text(verbatim: "CopyKat")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Delete backward"))
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}

// The globe has to be the UIKit button wired to the system selector; SwiftUI
// cannot express that handler.
private struct UIKitButton: UIViewRepresentable {
    let button: UIButton

    func makeUIView(context: Context) -> UIButton { button }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}
