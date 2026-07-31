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

    // Spotlight takes keyboard input without becoming the frontmost app, so a
    // keystroke posted to the session tap lands in the app behind it instead.
    // Only the HID tap reaches it. Regression: pasting into Spotlight quietly
    // went to whatever was underneath.
    func testUsesTheHidTapSoSpotlightReceivesTheKeystroke() {
        XCTAssertEqual(PasteKeystrokeGate.tap(flags: []), .cghidEventTap)
        XCTAssertEqual(PasteKeystrokeGate.tap(flags: [.capsLock, .function]), .cghidEventTap)
    }

    // The HID tap is only safe once the user has let go: a ⌘ injected there
    // while the real one is still down can stay latched until the screen is
    // locked. If the wait times out we would rather miss Spotlight.
    func testFallsBackToTheSessionTapWhileModifiersAreStillHeld() {
        XCTAssertEqual(PasteKeystrokeGate.tap(flags: [.command]), .cgAnnotatedSessionEventTap)
        XCTAssertEqual(PasteKeystrokeGate.tap(flags: [.command, .shift]), .cgAnnotatedSessionEventTap)
    }

    // The two decisions have to agree: whenever the gate says to wait, the tap
    // must still be the safe one, and whenever it posts without waiting the
    // keystroke must be able to reach Spotlight.
    func testTapAndGateAgreeOnWhenHoldingIsUnsafe() {
        for flags: NSEvent.ModifierFlags in [[], [.command], [.shift], [.control], [.option], [.capsLock]] {
            let postsImmediately = PasteKeystrokeGate.shouldPost(flags: flags, waited: 0)
            let usesHid = PasteKeystrokeGate.tap(flags: flags) == .cghidEventTap
            XCTAssertEqual(postsImmediately, usesHid, "disagreement for \(flags)")
        }
    }
}
