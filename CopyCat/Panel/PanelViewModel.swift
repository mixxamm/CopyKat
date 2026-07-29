import Foundation
import Observation
import SwiftData

// A run of consecutive items from the same app, rendered under one shared
// app header when it holds more than one item.
struct PanelSection: Equatable {
    let sourceAppBundleID: String?
    let sourceAppName: String?
    let items: [ClipboardItem]
    let firstIndex: Int

    var isGrouped: Bool { items.count >= 2 }
    var id: PersistentIdentifier { items[0].persistentModelID }
}

@MainActor
@Observable
final class PanelViewModel {
    private let store: HistoryStore

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            selectedIndex = 0
            refresh()
        }
    }
    private(set) var items: [ClipboardItem] = []
    var selectedIndex = 0

    var selectedItem: ClipboardItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    var sections: [PanelSection] {
        var sections: [PanelSection] = []
        var run: [ClipboardItem] = []

        func closeRun(endingBefore index: Int) {
            guard let first = run.first else { return }
            sections.append(PanelSection(
                sourceAppBundleID: first.sourceAppBundleID,
                sourceAppName: first.sourceAppName,
                items: run,
                firstIndex: index - run.count
            ))
            run = []
        }

        for (index, item) in items.enumerated() {
            if let previous = run.last {
                let sameRun = previous.sourceAppBundleID != nil
                    && previous.sourceAppBundleID == item.sourceAppBundleID
                    && previous.isPinned == item.isPinned
                if !sameRun {
                    closeRun(endingBefore: index)
                }
            }
            run.append(item)
        }
        closeRun(endingBefore: items.count)
        return sections
    }

    init(store: HistoryStore) {
        self.store = store
    }

    func reset() {
        query = ""
        selectedIndex = 0
        refresh()
    }

    func refresh() {
        items = store.items(matching: query)
        clampSelection()
    }

    func moveSelection(_ delta: Int) {
        selectedIndex += delta
        clampSelection()
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        store.delete(item)
        refresh()
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        store.togglePin(item)
        refresh()
    }

    private func clampSelection() {
        selectedIndex = items.isEmpty ? 0 : min(max(selectedIndex, 0), items.count - 1)
    }
}
