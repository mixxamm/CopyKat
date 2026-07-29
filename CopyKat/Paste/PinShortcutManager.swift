import Foundation
import KeyboardShortcuts

// Every pinned item can carry a global shortcut that pastes it directly,
// registered under a dynamic KeyboardShortcuts name derived from the item's
// pinShortcutID. sync() reconciles the registrations with the current pins.
@MainActor
final class PinShortcutManager {
    private let pinnedItems: () -> [ClipboardItem]
    private let paste: (ClipboardItem) -> Void
    private var registered: Set<String> = []

    init(pinnedItems: @escaping () -> [ClipboardItem], paste: @escaping (ClipboardItem) -> Void) {
        self.pinnedItems = pinnedItems
        self.paste = paste
    }

    nonisolated static func shortcutName(for id: String) -> KeyboardShortcuts.Name {
        KeyboardShortcuts.Name("pastePin-\(id)")
    }

    nonisolated static func diff(registered: Set<String>, currentIDs: Set<String>) -> (add: Set<String>, remove: Set<String>) {
        (add: currentIDs.subtracting(registered), remove: registered.subtracting(currentIDs))
    }

    func sync() {
        let currentIDs = Set(pinnedItems().compactMap(\.pinShortcutID))
        let changes = Self.diff(registered: registered, currentIDs: currentIDs)

        for id in changes.remove {
            // Also forgets the recorded key combination, so a later pin starts clean.
            KeyboardShortcuts.reset(Self.shortcutName(for: id))
            registered.remove(id)
        }
        for id in changes.add {
            KeyboardShortcuts.onKeyDown(for: Self.shortcutName(for: id)) { [weak self] in
                guard let self,
                      let item = self.pinnedItems().first(where: { $0.pinShortcutID == id })
                else { return }
                self.paste(item)
            }
            registered.insert(id)
        }
    }
}
