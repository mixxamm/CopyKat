import XCTest
import SwiftData
@testable import CopyKat

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var store: HistoryStore!
    private var externalCopyCount = 0
    private var imageDirectory: URL!

    override func setUpWithError() throws {
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryStoreTests-\(UUID().uuidString)")
        let imageStore = try ImageStore(directory: imageDirectory)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
        store = HistoryStore(container: container, imageStore: imageStore)
        store.visionIndexingEnabled = false
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: imageDirectory)
    }

    private func textCandidate(_ text: String, app: String? = nil) -> ClipboardCandidate {
        ClipboardCandidate(content: .text(text), sourceAppBundleID: app, sourceAppName: app)
    }

    private func pngFixture() throws -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    func testAddStoresTextNewestFirst() throws {
        try store.add(textCandidate("first"))
        try store.add(textCandidate("second"))
        let items = store.items(matching: "")
        XCTAssertEqual(items.map(\.text), ["second", "first"])
    }

    func testDuplicateMovesToTopWithoutNewRow() throws {
        try store.add(textCandidate("a"))
        try store.add(textCandidate("b"))
        try store.add(textCandidate("a"))
        let items = store.items(matching: "")
        XCTAssertEqual(items.map(\.text), ["a", "b"])
    }

    func testAddImageStoresFileAndDimensions() throws {
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))
        let item = try XCTUnwrap(store.items(matching: "").first)
        XCTAssertEqual(item.kind, .image)
        XCTAssertEqual(item.imageWidth, 4)
        XCTAssertNotNil(item.imageFilename)
    }

    func testTrimRemovesOldestUnpinnedBeyondLimit() throws {
        store.maxItems = 3
        try store.add(textCandidate("one"))
        store.togglePin(store.items(matching: "").first!)
        for text in ["two", "three", "four", "five"] {
            try store.add(textCandidate(text))
        }
        let items = store.items(matching: "")
        XCTAssertEqual(items.map(\.text), ["one", "five", "four", "three"])
        XCTAssertTrue(items[0].isPinned)
    }

    func testDeleteItemsOlderThanSparesRecentAndPinnedOnes() throws {
        try store.add(textCandidate("ancient"))
        try store.add(textCandidate("pinned but ancient"))
        try store.add(textCandidate("fresh"))

        let items = store.items(matching: "")
        let old = Date().addingTimeInterval(-60 * 60 * 24 * 90)
        try XCTUnwrap(items.first { $0.text == "ancient" }).createdAt = old
        let pinned = try XCTUnwrap(items.first { $0.text == "pinned but ancient" })
        pinned.createdAt = old
        store.togglePin(pinned)

        let removed = store.deleteItems(olderThan: Date().addingTimeInterval(-60 * 60 * 24 * 30))

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(Set(store.items(matching: "").compactMap(\.text)), ["pinned but ancient", "fresh"])
    }

    func testDeleteImagesOnlyLeavesOldTextAlone() throws {
        try store.add(textCandidate("old text"))
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))

        let old = Date().addingTimeInterval(-60 * 60 * 24 * 90)
        for item in store.items(matching: "") {
            item.createdAt = old
        }

        let removed = store.deleteItems(
            olderThan: Date().addingTimeInterval(-60 * 60 * 24 * 30),
            imagesOnly: true
        )

        XCTAssertEqual(removed, 1)
        XCTAssertEqual(store.items(matching: "").compactMap(\.text), ["old text"])
        XCTAssertEqual(store.storageUsage().imageItems, 0)
    }

    func testDeleteImagesOnlySparesAPinnedImage() throws {
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))
        let image = try XCTUnwrap(store.items(matching: "").first)
        image.createdAt = Date().addingTimeInterval(-60 * 60 * 24 * 90)
        store.togglePin(image)

        let removed = store.deleteItems(
            olderThan: Date().addingTimeInterval(-60 * 60 * 24 * 30),
            imagesOnly: true
        )

        XCTAssertEqual(removed, 0)
        XCTAssertEqual(store.storageUsage().imageItems, 1)
    }

    func testStorageUsageCountsImagesAndText() throws {
        try store.add(textCandidate("some text"))
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))

        let usage = store.storageUsage()
        XCTAssertEqual(usage.textItems, 1)
        XCTAssertEqual(usage.imageItems, 1)
        XCTAssertGreaterThan(usage.imageBytes, 0)
    }

    func testUnlimitedHistoryKeepsEverything() throws {
        store.maxItems = nil
        for index in 0..<25 {
            try store.add(textCandidate("item \(index)"))
        }
        XCTAssertEqual(store.items(matching: "").count, 25)
    }

    func testPinnedItemsSurviveTrimAndSortFirst() throws {
        store.maxItems = 2
        try store.add(textCandidate("keep"))
        store.togglePin(store.items(matching: "").first!)
        for text in ["x", "y", "z"] { try store.add(textCandidate(text)) }
        let items = store.items(matching: "")
        XCTAssertEqual(items.first?.text, "keep")
        XCTAssertEqual(items.count, 3)
    }

    func testFuzzySearchToleratesTypos() throws {
        try store.add(textCandidate("CopyKat repository link"))
        try store.add(textCandidate("banana bread recipe"))

        let hits = store.items(matching: "copkat")
        XCTAssertEqual(hits.first?.text, "CopyKat repository link")
        XCTAssertFalse(hits.contains { $0.text == "banana bread recipe" })
    }

    func testFuzzySearchRanksCloserMatchFirst() throws {
        try store.add(textCandidate("banana"))
        try store.add(textCandidate("bandana"))

        XCTAssertEqual(store.items(matching: "banana").first?.text, "banana")
    }

    func testSearchMatchesTextAndSourceApp() throws {
        try store.add(textCandidate("invoice draft"))
        try store.add(textCandidate("hello", app: "Safari"))
        XCTAssertEqual(store.items(matching: "invoice").count, 1)
        XCTAssertEqual(store.items(matching: "safari").count, 1)
        XCTAssertEqual(store.items(matching: "nothing").count, 0)
    }

    func testDeleteRemovesImageFile() throws {
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))
        let item = try XCTUnwrap(store.items(matching: "").first)
        let filename = try XCTUnwrap(item.imageFilename)
        store.delete(item)
        XCTAssertTrue(store.items(matching: "").isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent(filename).path))
    }

    func testDeleteAllKeepsOnlyPinnedItems() throws {
        try store.add(textCandidate("one"))
        try store.add(textCandidate("two"))
        try store.add(textCandidate("three"))
        let toPin = try XCTUnwrap(store.items(matching: "").first { $0.text == "two" })
        store.togglePin(toPin)

        store.deleteAll()

        let items = store.items(matching: "")
        XCTAssertEqual(items.map(\.text), ["two"])
        XCTAssertTrue(items[0].isPinned)
    }

    func testAFreshCopyReportsAnExternalCopyButOurOwnPasteDoesNot() throws {
        let tracker = SelfWriteTracker()
        store.selfWriteTracker = tracker
        var externalCopies = 0
        store.externalCopyArrived = { externalCopies += 1 }

        try store.add(textCandidate("typed by hand"))
        XCTAssertEqual(externalCopies, 1)

        let item = try XCTUnwrap(store.items(matching: "").first)
        tracker.record(hash: item.contentHash)
        try store.add(textCandidate("typed by hand"))
        XCTAssertEqual(externalCopies, 1, "pasting from CopyKat is not a new copy")

        try store.add(textCandidate("copied again"))
        XCTAssertEqual(externalCopies, 2)
    }

    func testRecopyingAnExistingItemAlsoCountsAsAnExternalCopy() throws {
        store.externalCopyArrived = { self.externalCopyCount += 1 }
        try store.add(textCandidate("a"))
        try store.add(textCandidate("b"))
        externalCopyCount = 0

        try store.add(textCandidate("a"))

        XCTAssertEqual(externalCopyCount, 1)
    }

    func testOurOwnPasteDoesNotMoveTheItemBackToTheTop() throws {
        let tracker = SelfWriteTracker()
        store.selfWriteTracker = tracker

        try store.add(textCandidate("older"))
        try store.add(textCandidate("newer"))
        let older = try XCTUnwrap(store.items(matching: "").first { $0.text == "older" })
        let originalDate = older.createdAt

        // Pasting "older" puts it back on the pasteboard; the monitor sees it.
        tracker.record(hash: older.contentHash)
        try store.add(textCandidate("older"))

        XCTAssertEqual(store.items(matching: "").map(\.text), ["newer", "older"])
        XCTAssertEqual(older.createdAt, originalDate)
    }

    func testACopyFromAnotherAppStillMovesTheItemToTheTop() throws {
        let tracker = SelfWriteTracker()
        store.selfWriteTracker = tracker

        try store.add(textCandidate("older"))
        try store.add(textCandidate("newer"))
        tracker.record(hash: "text:something-else")

        try store.add(textCandidate("older"))

        XCTAssertEqual(store.items(matching: "").map(\.text), ["older", "newer"])
    }

    func testAddPersistsRemoteFlag() throws {
        try store.add(ClipboardCandidate(
            content: .text("from iPhone"), sourceAppBundleID: nil, sourceAppName: nil, isRemote: true
        ))
        let item = try XCTUnwrap(store.items(matching: "").first)
        XCTAssertTrue(item.isRemote)
    }

    func testPinningAssignsShortcutIDAndUnpinningClearsIt() throws {
        try store.add(textCandidate("snippet"))
        let item = try XCTUnwrap(store.items(matching: "").first)
        XCTAssertNil(item.pinShortcutID)

        store.togglePin(item)
        let assigned = try XCTUnwrap(item.pinShortcutID)
        XCTAssertFalse(assigned.isEmpty)

        store.togglePin(item)
        XCTAssertNil(item.pinShortcutID)
    }

    func testPinsChangedFiresOnPinTogglesAndPinnedDeletes() throws {
        var fired = 0
        store.pinsChanged = { fired += 1 }
        try store.add(textCandidate("a"))
        try store.add(textCandidate("b"))
        let a = try XCTUnwrap(store.items(matching: "").first { $0.text == "a" })
        let b = try XCTUnwrap(store.items(matching: "").first { $0.text == "b" })

        store.togglePin(a)
        XCTAssertEqual(fired, 1)
        store.delete(b)
        XCTAssertEqual(fired, 1)
        store.delete(a)
        XCTAssertEqual(fired, 2)
    }

    func testMigrationRewritesLegacyTextHashesSoDedupeWorksAgain() throws {
        let item = try XCTUnwrap(store.add(textCandidate("hello")))
        item.contentHash = "text:hello"

        store.migrateLegacyContentHashes()

        let migrated = try XCTUnwrap(store.items(matching: "").first)
        XCTAssertTrue(migrated.contentHash.hasPrefix("text:"))
        XCTAssertEqual(migrated.contentHash.count, "text:".count + 64)
        try store.add(textCandidate("hello"))
        XCTAssertEqual(store.items(matching: "").count, 1)
    }

    func testMigrationCollapsesLegacyDuplicates() throws {
        let legacy = try XCTUnwrap(store.add(textCandidate("dup")))
        legacy.contentHash = "text:dup"
        legacy.isPinned = true
        try store.add(textCandidate("dup"))
        XCTAssertEqual(store.items(matching: "").count, 2)

        store.migrateLegacyContentHashes()

        let items = store.items(matching: "")
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].isPinned)
    }

    func testPruneOrphansDropsItemsWithMissingFilesAndStrayFiles() throws {
        try store.add(ClipboardCandidate(content: .image(pngFixture()), sourceAppBundleID: nil, sourceAppName: nil))
        let item = try XCTUnwrap(store.items(matching: "").first)
        try FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(item.imageFilename!))
        try Data([0x1]).write(to: imageDirectory.appendingPathComponent("stray.png"))
        store.pruneOrphans()
        XCTAssertTrue(store.items(matching: "").isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageDirectory.appendingPathComponent("stray.png").path))
    }
}
