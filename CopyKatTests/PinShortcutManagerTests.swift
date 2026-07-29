import XCTest
@testable import CopyKat

final class PinShortcutManagerTests: XCTestCase {
    func testDiffRegistersNewAndResetsRemovedIDs() {
        let result = PinShortcutManager.diff(registered: ["a", "b"], currentIDs: ["b", "c"])
        XCTAssertEqual(result.add, ["c"])
        XCTAssertEqual(result.remove, ["a"])
    }

    func testDiffIsEmptyWhenNothingChanged() {
        let result = PinShortcutManager.diff(registered: ["a"], currentIDs: ["a"])
        XCTAssertTrue(result.add.isEmpty)
        XCTAssertTrue(result.remove.isEmpty)
    }

    func testShortcutNameIsStablePerID() {
        XCTAssertEqual(PinShortcutManager.shortcutName(for: "xyz").rawValue, "pastePin-xyz")
    }
}
