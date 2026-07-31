import SwiftData
import UIKit
import UniformTypeIdentifiers

// Capture from the share sheet: whatever the user hands over goes straight
// into the shared store, and the sheet closes. Unlike the keyboard, a share
// extension may write to the app group, so it uses the real store.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await captureAndFinish() }
    }

    private func captureAndFinish() async {
        let providers = (extensionContext?.inputItems ?? [])
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }

        var contents: [(ClipboardCandidate.Content, String?)] = []
        for provider in providers {
            if let content = await load(from: provider) {
                contents.append(content)
            }
        }

        if !contents.isEmpty {
            save(contents)
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    // Order matters: a shared image often also carries a URL to itself, and
    // the image is what the user meant. iOS deliberately hides the sharing
    // app's identity from extensions, so the closest honest source label is
    // the website's host when a link is shared, and nothing otherwise.
    private func load(from provider: NSItemProvider) async -> (ClipboardCandidate.Content, String?)? {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let data = try? await provider.loadDataRepresentation(for: .png) {
                return (.image(data), nil)
            }
            if let data = try? await provider.loadDataRepresentation(for: .image),
               let image = UIImage(data: data), let png = image.pngData() {
                return (.image(png), nil)
            }
            return nil
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
            return (.text(url.absoluteString), url.host)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
            return (.text(text), nil)
        }
        return nil
    }

    @MainActor
    private func save(_ contents: [(ClipboardCandidate.Content, String?)]) {
        guard let root = AppGroup.container else { return }
        let dataDirectory = root.appendingPathComponent("CopyKat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        guard let imageStore = try? ImageStore(directory: dataDirectory.appendingPathComponent("Images")),
              let container = try? ModelContainer(
                for: ClipboardItem.self,
                configurations: ModelConfiguration(url: dataDirectory.appendingPathComponent("History.store"))
              )
        else { return }

        let store = HistoryStore(container: container, imageStore: imageStore)
        // No OCR in the extension: its memory ceiling is tight, and the app
        // backfills unindexed images the next time it runs.
        store.visionIndexingEnabled = false
        for (content, source) in contents {
            try? store.add(ClipboardCandidate(content: content, sourceAppBundleID: nil, sourceAppName: source))
        }
        KeyboardSnapshot.write(items: store.items(matching: ""), to: root)
    }
}

private extension NSItemProvider {
    func loadDataRepresentation(for type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadDataRepresentation(for: type) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }
}
