import XCTest
@testable import KopyKat

@MainActor
final class PasteServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var service: PasteService!
    private var imageStore: ImageStore!
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PasteServiceTests-\(UUID().uuidString)")
        imageStore = try ImageStore(directory: directory)
        service = PasteService(imageStore: imageStore)
        pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteServiceTests-\(UUID().uuidString)"))
    }

    override func tearDownWithError() throws {
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }

    func testWritesText() {
        let item = ClipboardItem(kind: .text, text: "hello", contentHash: "text:hello")
        XCTAssertTrue(service.write(item, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "hello")
    }

    func testWritesFileURL() {
        let item = ClipboardItem(kind: .fileURL, text: "/tmp/x.pdf", contentHash: "file:/tmp/x.pdf")
        XCTAssertTrue(service.write(item, to: pasteboard))
        let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        XCTAssertEqual(urls?.first?.path, "/tmp/x.pdf")
    }

    func testWritesImageAsPNG() throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let saved = try imageStore.save(pngData: png)
        let item = ClipboardItem(
            kind: .image, imageFilename: saved.filename,
            imageWidth: saved.width, imageHeight: saved.height,
            contentHash: "image:\(saved.hash)"
        )
        XCTAssertTrue(service.write(item, to: pasteboard))
        XCTAssertNotNil(pasteboard.data(forType: .png))
    }

    func testMissingImageFileLeavesClipboardUntouched() throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let saved = try imageStore.save(pngData: png)
        try FileManager.default.removeItem(at: imageStore.imageURL(for: saved.filename))
        let item = ClipboardItem(
            kind: .image, imageFilename: saved.filename,
            imageWidth: saved.width, imageHeight: saved.height,
            contentHash: "image:\(saved.hash)"
        )

        pasteboard.clearContents()
        pasteboard.setString("preserve me", forType: .string)

        XCTAssertFalse(service.write(item, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "preserve me")
    }
}
