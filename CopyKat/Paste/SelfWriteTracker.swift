import Foundation

// Pasting puts the item back on the pasteboard, which the monitor would
// otherwise capture as a fresh copy and bump to the top of the history.
// PasteService records the change count of its own write here so the monitor
// can skip exactly that one change.
@MainActor
final class SelfWriteTracker {
    private var pendingChangeCount: Int?

    func record(changeCount: Int) {
        pendingChangeCount = changeCount
    }

    // Returns true when this change came from our own paste, and forgets it.
    func consumeIfSelfWrite(changeCount: Int) -> Bool {
        guard pendingChangeCount == changeCount else { return false }
        pendingChangeCount = nil
        return true
    }
}
