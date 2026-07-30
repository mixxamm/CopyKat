import XCTest
@testable import CopyKat

final class PasteKeystrokeGateTests: XCTestCase {
    func testPostsImmediatelyWhenNoModifiersAreHeld() {
        XCTAssertTrue(PasteKeystrokeGate.shouldPost(flags: [], waited: 0))
    }

    func testWaitsWhileTheUserStillHoldsTheHotkey() {
        XCTAssertFalse(PasteKeystrokeGate.shouldPost(flags: [.command, .shift], waited: 0))
        XCTAssertFalse(PasteKeystrokeGate.shouldPost(flags: [.command], waited: 0.3))
    }

    func testIgnoresModifiersThatCannotMergeIntoTheKeystroke() {
        XCTAssertTrue(PasteKeystrokeGate.shouldPost(flags: [.capsLock, .function], waited: 0))
    }

    func testPostsAnywayOnceTheWaitRunsOut() {
        XCTAssertTrue(PasteKeystrokeGate.shouldPost(flags: [.command], waited: PasteKeystrokeGate.timeout))
    }
}
