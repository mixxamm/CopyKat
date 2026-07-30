import Foundation
import Observation
import SwiftData

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

    // True while a fast-paste session is running: releasing the hotkey's
    // modifiers pastes the selection, and the search field hints at the
    // double-tap escape.
    var isFastSession = false

    // Bumped on every open. The panel view is reused between showings, so the
    // list needs an explicit signal to scroll the selection back into place.
    private(set) var openToken = 0

    // Snapshotted per showing rather than read straight from AppSettings: a
    // stored property is observable, so the panel resizes when the list comes
    // and goes. The setting can only change while the panel is closed anyway.
    private(set) var hidesList = AppSettings.hideListUntilSearch

    // Searching without seeing what you matched is useless, so any query brings
    // the list back however the setting is left.
    var listIsVisible: Bool {
        !hidesList || !query.isEmpty
    }

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

    init(store: HistoryStore) {
        self.store = store
    }

    func reset() {
        query = ""
        hidesList = AppSettings.hideListUntilSearch
        refresh()
        // Pick up where the user left off: highlight the item pasted last,
        // even when newer copies have stacked on top of it since.
        let remembered = AppSettings.lastPastedContentHash.flatMap { hash in
            items.first { $0.contentHash == hash }
        }
        selectedID = (remembered ?? items.first)?.persistentModelID
    }

    // Called once the panel is actually on screen. Centering during reset()
    // does nothing: the window is not laid out yet, so scrollTo is a no-op and
    // the list stays at offset zero until the first arrow key.
    func panelDidAppear() {
        openToken += 1
    }

    func refresh() {
        let previousOrder = items.map(\.persistentModelID)
        items = store.items(matching: query)
        if selectedItem == nil {
            selectedID = items.first?.persistentModelID
        }
        // A copy made while the panel is open pushes every row down, so the
        // selection has to be pulled back to the centre line.
        if items.map(\.persistentModelID) != previousOrder {
            openToken += 1
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
