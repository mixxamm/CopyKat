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
            refresh()
            selectedID = items.first?.persistentModelID
        }
    }
    private(set) var items: [ClipboardItem] = []

    // Selection follows the item, not its position. Index-based selection can
    // highlight the wrong row (or two rows) when a live refresh shifts the list
    // between renders; identities cannot collide.
    private(set) var selectedID: PersistentIdentifier?

    var selectedItem: ClipboardItem? {
        items.first { $0.persistentModelID == selectedID }
    }

    var selectedIndex: Int? {
        items.firstIndex { $0.persistentModelID == selectedID }
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
        refresh()
        selectedID = items.first?.persistentModelID
    }

    func refresh() {
        items = store.items(matching: query)
        if selectedItem == nil {
            selectedID = items.first?.persistentModelID
        }
    }

    func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        let current = selectedIndex ?? 0
        let target = min(max(current + delta, 0), items.count - 1)
        selectedID = items[target].persistentModelID
    }

    func deleteSelected() {
        guard let item = selectedItem else { return }
        delete(item)
    }

    func togglePinSelected() {
        guard let item = selectedItem else { return }
        togglePin(item)
    }

    func delete(_ item: ClipboardItem) {
        let previousIndex = selectedIndex
        let deletingSelected = item.persistentModelID == selectedID
        store.delete(item)
        items = store.items(matching: query)
        if deletingSelected, let previousIndex, !items.isEmpty {
            selectedID = items[min(previousIndex, items.count - 1)].persistentModelID
        } else if selectedItem == nil {
            selectedID = items.first?.persistentModelID
        }
    }

    func togglePin(_ item: ClipboardItem) {
        store.togglePin(item)
        refresh()
    }

    // Position is 1-based to match the ⌘1…⌘9 keys.
    func quickPasteItem(at position: Int) -> ClipboardItem? {
        guard (1...9).contains(position), items.indices.contains(position - 1) else { return nil }
        return items[position - 1]
    }
}
