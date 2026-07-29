import XCTest
@testable import CopyKat

final class ImageStoreTests: XCTestCase {
    private var directory: URL!
    private var store: ImageStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageStoreTests-\(UUID().uuidString)")
        store = try ImageStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func pngFixture(width: Int = 12, height: Int = 8) throws -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    func testSaveWritesFileAndReportsDimensions() throws {
        let saved = try store.save(pngData: pngFixture(width: 12, height: 8))
        XCTAssertEqual(saved.width, 12)
        XCTAssertEqual(saved.height, 8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(for: saved.filename).path))
    }

    func testSavingSameDataTwiceReusesFile() throws {
        let data = try pngFixture()
        let first = try store.save(pngData: data)
        let second = try store.save(pngData: data)
        XCTAssertEqual(first, second)
        XCTAssertEqual(store.existingFilenames().count, 1)
    }

    func testSaveRejectsGarbageData() {
        XCTAssertThrowsError(try store.save(pngData: Data([0x00, 0x01])))
    }

    func testLoadAndThumbnail() throws {
        let saved = try store.save(pngData: pngFixture(width: 100, height: 50))
        XCTAssertNotNil(store.loadImage(named: saved.filename))
        let thumb = try XCTUnwrap(store.thumbnail(for: saved.filename, maxDimension: 40))
        XCTAssertLessThanOrEqual(max(thumb.size.width, thumb.size.height), 40)
    }

    func testDeleteRemovesFile() throws {
        let saved = try store.save(pngData: pngFixture())
        store.delete(named: saved.filename)
        XCTAssertTrue(store.existingFilenames().isEmpty)
        XCTAssertNil(store.loadImage(named: saved.filename))
    }
}
