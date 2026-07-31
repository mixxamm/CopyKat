import SwiftData
import SwiftUI

@main
struct CopyKatiOSApp: App {
    @State private var model = PhoneAppModel()

    var body: some Scene {
        WindowGroup {
            HistoryView(model: model)
                .tint(.brand)
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
    private(set) var syncTransports: [any SyncTransport] = []

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

        // Images the share extension captured skipped OCR (its memory ceiling
        // is tight); pick them up here, exactly like the Mac does at launch.
        historyStore.backfillVisionIndex()

        cloudSync = CloudSyncController(store: historyStore, imageStore: imageStore, stateDirectory: dataDirectory)
        syncTransports = [cloudSync].compactMap { $0 }
        historyStore.historyChanged = { [weak self] in
            self?.syncTransports.forEach { $0.scheduleReconcile() }
        }
        syncTransports.forEach { $0.start() }
    }

    // Pull-to-refresh: sync first when enabled, then reread the store.
    func refreshFromCloud() async {
        await cloudSync?.fetchNow()
    }

    func cloudSyncSettingsChanged() {
        if AppSettings.cloudSyncEnabled {
            syncTransports.forEach { $0.start(); $0.scheduleReconcile() }
        } else {
            syncTransports.forEach { $0.stop() }
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
