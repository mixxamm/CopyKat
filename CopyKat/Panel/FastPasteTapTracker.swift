import Foundation

// Fast paste sessions: the first hotkey press opens the panel, a quick second
// press switches to search, and anything later just advances the selection.
// The search escape only lives on press two: rapid cycling deeper into the
// list (⌘Tab-style) must never drop the user into the search field.
struct FastPasteTapTracker {
    enum Action: Equatable {
        case open
        case enterSearch
        case advance
    }

    private let doubleTapWindow: TimeInterval = 0.35
    private var pressCount = 0
    private var firstPressAt: Date?

    mutating func register(at date: Date = .now) -> Action {
        pressCount += 1
        switch pressCount {
        case 1:
            firstPressAt = date
            return .open
        case 2 where firstPressAt.map({ date.timeIntervalSince($0) <= doubleTapWindow }) == true:
            return .enterSearch
        default:
            return .advance
        }
    }

    mutating func reset() {
        pressCount = 0
        firstPressAt = nil
    }
}
