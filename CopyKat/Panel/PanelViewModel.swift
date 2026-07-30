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

// One flat sequence of things to draw, so every row is its own scroll target.
// Headers must not share an identity with their first row: two views with the
// same id make SwiftUI draw duplicates and leave scrollTo aiming at the wrong
// one.
enum PanelEntryID: Hashable {
    case header(PersistentIdentifier)
    case row(PersistentIdentifier)
}

enum PanelEntry: Identifiable {
    case header(PanelSection)
    case row(item: ClipboardItem, index: Int, indented: Bool, showsSourceApp: Bool)

    var id: PanelEntryID {
        switch self {
        case .header(let section): .header(section.id)
        case .row(let item, _, _, _): .row(item.persistentModelID)
        }
    }
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

    // True while a fast-paste session is running: releasing the hotkey's
    // modifiers pastes the selection, and the search field hints at the
    // double-tap escape.
    var isFastSession = false

    // Bumped on every open. The panel view is reused between showings, so the
    // list needs an explicit signal to scroll the selection back into place.
    private(set) var openToken = 0

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

    var entries: [PanelEntry] {
        sections.flatMap { section -> [PanelEntry] in
            let rows = section.items.enumerated().map { offset, item in
                PanelEntry.row(
                    item: item,
                    index: section.firstIndex + offset,
                    indented: section.isGrouped,
                    showsSourceApp: !section.isGrouped
                )
            }
            return section.isGrouped ? [.header(section)] + rows : rows
        }
    }

    init(store: HistoryStore) {
        self.store = store
    }

    func reset() {
        query = ""
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
