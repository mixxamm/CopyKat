import XCTest
@testable import CopyKat

final class FastPasteTapTrackerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    func testFirstPressOpens() {
        var tracker = FastPasteTapTracker()
        XCTAssertEqual(tracker.register(at: t0), .open)
    }

    func testQuickSecondPressEntersSearchWithoutUndo() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.2)), .enterSearch(undoAdvance: false))
    }

    func testSlowSecondPressAdvances() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.6)), .advance)
    }

    func testDoubleTapDuringCyclingEntersSearchAndUndoesTheStrayAdvance() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.6)), .advance)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(1.2)), .advance)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(1.35)), .enterSearch(undoAdvance: true))
    }

    func testDeliberateCyclingKeepsAdvancingWhenSpacedOut() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.5)), .advance)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(1.0)), .advance)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(1.5)), .advance)
    }

    func testResetStartsANewSession() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        tracker.reset()
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.1)), .open)
    }
}
