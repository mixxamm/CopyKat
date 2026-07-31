import SwiftUI
import UIKit

// The keyboard is a picker, not a typing surface: the history as a list, tap
// to insert, globe to get Apple's keyboard back. It runs without Full Access,
// which is why it reads the snapshot the app maintains and nothing else.
final class KeyboardViewController: UIInputViewController {
    private var snapshot = KeyboardSnapshot()

    override func viewDidLoad() {
        super.viewDidLoad()
        if let container = AppGroup.container {
            snapshot = KeyboardSnapshot.read(from: container)
        }

        let root = KeyboardView(
            entries: sortedEntries,
            needsGlobe: needsInputModeSwitchKey,
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
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
    let needsGlobe: Bool
    let onInsert: (String) -> Void
    let onDelete: () -> Void
    let globe: () -> UIButton?

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(entries) { entry in
                            row(for: entry)
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

    private func row(for entry: KeyboardSnapshot.Entry) -> some View {
        Button {
            onInsert(entry.text)
        } label: {
            HStack(spacing: 8) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
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
