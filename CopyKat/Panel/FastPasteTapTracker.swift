import Foundation

// Fast paste sessions: the first hotkey press opens the panel, further presses
// advance the selection, and two presses in quick succession switch to search
// at any point in the session. When the double-tap follows earlier cycling,
// its first tap already advanced the selection; the action says so, letting
// the caller undo that step.
struct FastPasteTapTracker {
    enum Action: Equatable {
        case open
        case advance
        case enterSearch(undoAdvance: Bool)
    }

    private let doubleTapWindow: TimeInterval = 0.3
    private var pressCount = 0
    private var lastPressAt: Date?

    mutating func register(at date: Date = .now) -> Action {
        pressCount += 1
        defer { lastPressAt = date }

        if pressCount == 1 {
            return .open
        }
        if let last = lastPressAt, date.timeIntervalSince(last) <= doubleTapWindow {
            return .enterSearch(undoAdvance: pressCount >= 3)
        }
        return .advance
    }

    mutating func reset() {
        pressCount = 0
        lastPressAt = nil
    }
}
