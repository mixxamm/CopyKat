import SwiftData
import SwiftUI

@main
struct CopyKatiOSApp: App {
    @State private var model = PhoneAppModel()

    var body: some Scene {
        WindowGroup {
            HistoryView(model: model)
        }
    }
}

// The phone-side counterpart of AppState: owns the store and the two actions
// the platform allows, capturing what the user hands over and putting an item
// back on the clipboard.
@MainActor
@Observable
final class PhoneAppModel {
    let historyStore: HistoryStore
    let imageStore: ImageStore
    private(set) var cloudSync: CloudSyncController?

    init() {
        // The store lives in the app group from day one: the share extension
        // writes into it, and moving a store later means migrating every user
        // twice.
        let root = AppGroup.container
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dataDirectory = root.appendingPathComponent("CopyKat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)

        do {
            imageStore = try ImageStore(directory: dataDirectory.appendingPathComponent("Images"))
            let configuration = ModelConfiguration(url: dataDirectory.appendingPathComponent("History.store"))
            let container = try ModelContainer(for: ClipboardItem.self, configurations: configuration)
            historyStore = HistoryStore(container: container, imageStore: imageStore)
            historyStore.maxItems = AppSettings.historyLimit
        } catch {
            fatalError("Could not open the history store: \(error)")
        }

        cloudSync = CloudSyncController(store: historyStore, imageStore: imageStore, stateDirectory: dataDirectory)
        historyStore.historyChanged = { [weak self] in
            self?.cloudSync?.scheduleReconcile()
        }
        cloudSync?.start()
    }

    func cloudSyncSettingsChanged() {
        if AppSettings.cloudSyncEnabled {
            cloudSync?.start()
            cloudSync?.scheduleReconcile()
        } else {
            cloudSync?.stop()
        }
    }

    // What the share sheet and the paste button both funnel into.
    func capture(_ content: ClipboardCandidate.Content) {
        try? historyStore.add(ClipboardCandidate(content: content, sourceAppBundleID: nil, sourceAppName: nil))
        refreshKeyboardSnapshot()
    }

    // The keyboard reads a snapshot, not the store; keep it current whenever
    // the history could have moved.
    func refreshKeyboardSnapshot() {
        guard let container = AppGroup.container else { return }
        KeyboardSnapshot.write(items: historyStore.items(matching: ""), to: container)
    }

    // Tapping an item puts it on the general pasteboard. Universal Clipboard
    // carries it to a nearby Mac; locally it is simply ready to paste.
    func copyToClipboard(_ item: ClipboardItem) {
        switch item.kind {
        case .text, .fileURL:
            if let text = item.text {
                UIPasteboard.general.string = text
            }
        case .image:
            if let filename = item.imageFilename,
               let data = try? Data(contentsOf: imageStore.imageURL(for: filename)),
               let image = UIImage(data: data) {
                UIPasteboard.general.image = image
            }
        }
    }
}
