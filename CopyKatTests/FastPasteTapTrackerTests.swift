import XCTest
@testable import CopyKat

final class FastPasteTapTrackerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1000)

    func testFirstPressOpens() {
        var tracker = FastPasteTapTracker()
        XCTAssertEqual(tracker.register(at: t0), .open)
    }

    func testQuickSecondPressEntersSearch() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.2)), .enterSearch)
    }

    func testSlowSecondPressAdvances() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.6)), .advance)
    }

    func testRapidCyclingAfterNavigationNeverEntersSearch() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        _ = tracker.register(at: t0.addingTimeInterval(0.6))
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.7)), .advance)
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.75)), .advance)
    }

    func testResetStartsANewSession() {
        var tracker = FastPasteTapTracker()
        _ = tracker.register(at: t0)
        tracker.reset()
        XCTAssertEqual(tracker.register(at: t0.addingTimeInterval(0.1)), .open)
    }
}
