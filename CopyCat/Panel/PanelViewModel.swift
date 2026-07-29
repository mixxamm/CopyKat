import Foundation
import Observation

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
