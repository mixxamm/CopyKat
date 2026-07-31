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
            selectedID = query.isEmpty ? defaultSelectionID : items.first?.persistentModelID
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
    private(set) var hidesSearch = AppSettings.hideSearchBar

    private(set) var vimNavigation = AppSettings.vimNavigation

    var searchIsVisible: Bool { !hidesSearch }

    // Letters can only stand in for the arrow keys while nothing is being
    // typed, or searching for anything containing h, j, k or l would be
    // impossible.
    var vimNavigationIsActive: Bool {
        vimNavigation && query.isEmpty
    }

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

    // Pins sit at the top of the list for reach, not because a session starts
    // there: the opening highlight is the newest copy, and pins are what you
    // deliberately navigate up to.
    private var defaultSelectionID: PersistentIdentifier? {
        (items.first { !$0.isPinned } ?? items.first)?.persistentModelID
    }

    func reset() {
        query = ""
        hidesList = AppSettings.hideListUntilSearch
        hidesSearch = AppSettings.hideSearchBar
        vimNavigation = AppSettings.vimNavigation
        refresh()
        // Pick up where the user left off: highlight the item pasted last,
        // even when newer copies have stacked on top of it since.
        let remembered = AppSettings.lastPastedContentHash.flatMap { hash in
            items.first { $0.contentHash == hash }
        }
        selectedID = remembered?.persistentModelID ?? defaultSelectionID
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
            // While searching the top row is the best match, pins included;
            // otherwise fall past the pins to the newest copy.
            selectedID = query.isEmpty ? defaultSelectionID : items.first?.persistentModelID
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
        store.deleteUndoably(item)
        items = store.items(matching: query)
        if deletingSelected, let previousIndex, !items.isEmpty {
            selectedID = items[min(previousIndex, items.count - 1)].persistentModelID
        } else if selectedItem == nil {
            selectedID = items.first?.persistentModelID
        }
    }

    var canUndoDelete: Bool { store.canUndoDelete }

    // Puts the last hand-deleted item back and highlights it, so the undo is
    // visible even when the row lands somewhere off screen.
    func undoDelete() {
        guard let restored = store.undoLastDelete() else { return }
        refresh()
        selectedID = restored.persistentModelID
        openToken += 1
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
