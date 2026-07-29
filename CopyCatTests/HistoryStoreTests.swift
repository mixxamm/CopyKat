import XCTest
import SwiftData
@testable import CopyCat

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var store: HistoryStore!
    private var imageDirectory: URL!

    override func setUpWithError() throws {
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HistoryStoreTests-\(UUID().uuidString)")
        let imageStore = try ImageStore(directory: imageDirectory)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
        store = HistoryStore(container: container, imageStore: imageStore)
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

    func testPinnedItemsSurviveTrimAndSortFirst() throws {
        store.maxItems = 2
        try store.add(textCandidate("keep"))
        store.togglePin(store.items(matching: "").first!)
        for text in ["x", "y", "z"] { try store.add(textCandidate(text)) }
        let items = store.items(matching: "")
        XCTAssertEqual(items.first?.text, "keep")
        XCTAssertEqual(items.count, 3)
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
