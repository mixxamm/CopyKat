import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftData
import XCTest
@testable import CopyKat

@MainActor
final class ImageIndexerTests: XCTestCase {
    private var store: HistoryStore!
    private var imageDirectory: URL!
    private let indexer = ImageIndexer()

    override func setUpWithError() throws {
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageIndexerTests-\(UUID().uuidString)")
        let imageStore = try ImageStore(directory: imageDirectory)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
        store = HistoryStore(container: container, imageStore: imageStore)
        store.visionIndexingEnabled = false
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: imageDirectory)
    }

    // Fixtures are generated, not checked in: an image with the text drawn
    // into it, and a QR code straight from CoreImage.
    private func textImage(_ text: String) -> Data {
        let size = NSSize(width: 480, height: 120)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        (text as NSString).draw(
            at: NSPoint(x: 20, y: 40),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 32),
                .foregroundColor: NSColor.black,
            ]
        )
        image.unlockFocus()
        let tiff = image.tiffRepresentation!
        return NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
    }

    private func qrImage(_ payload: String) -> Data {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        // Scale up: Vision wants more than the generator's tiny native output.
        let output = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let cg = CIContext().createCGImage(output, from: output.extent)!
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])!
    }

    func testReadsTextOutOfAnImage() {
        let insights = indexer.insights(for: textImage("Invoice 2478 draft"))
        let text = insights.recognizedText ?? ""
        XCTAssertTrue(text.contains("Invoice"), "got: \(text)")
        XCTAssertTrue(text.contains("2478"), "got: \(text)")
    }

    func testDecodesAQRCode() {
        let insights = indexer.insights(for: qrImage("https://copykat.dev/support/"))
        XCTAssertEqual(insights.qrPayload, "https://copykat.dev/support/")
    }

    func testGarbageDataYieldsEmptyInsightsWithoutCrashing() {
        XCTAssertEqual(indexer.insights(for: Data([0x00, 0x01, 0x02])), ImageInsights())
    }

    func testSearchFindsAnImageByItsRecognizedText() throws {
        try store.add(ClipboardCandidate(content: .text("unrelated"), sourceAppBundleID: nil, sourceAppName: nil))
        let item = try XCTUnwrap(store.add(ClipboardCandidate(
            content: .image(textImage("quarterly report")),
            sourceAppBundleID: nil, sourceAppName: nil
        )))
        // Apply synchronously: the test pins the plumbing, not the background hop.
        store.applyInsights(indexer.insights(for: textImage("quarterly report")), to: item)

        let hits = store.items(matching: "quarterly")
        XCTAssertEqual(hits.map(\.persistentModelID), [item.persistentModelID])
        XCTAssertTrue(item.visionIndexed)
    }

    func testSearchFindsAnImageByItsLabelsAndQRPayload() throws {
        let item = try XCTUnwrap(store.add(ClipboardCandidate(
            content: .image(qrImage("https://example.org/tickets")),
            sourceAppBundleID: nil, sourceAppName: nil
        )))
        var insights = ImageInsights()
        insights.qrPayload = "https://example.org/tickets"
        insights.labels = ["document", "receipt"]
        store.applyInsights(insights, to: item)

        XCTAssertEqual(store.items(matching: "tickets").count, 1)
        XCTAssertEqual(store.items(matching: "receipt").count, 1)
    }

    func testPasteAsTextDoesNotGrowTheHistory() throws {
        let paste = PasteService(imageStore: try ImageStore(directory: imageDirectory))
        store.selfWriteTracker = paste.selfWriteTracker
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ImageIndexerTests-\(UUID().uuidString)"))

        XCTAssertTrue(paste.writeText("recognized words", to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "recognized words")

        // The monitor would now capture this text; the tracker must veto it.
        try store.add(ClipboardCandidate(content: .text("recognized words"), sourceAppBundleID: nil, sourceAppName: nil))
        XCTAssertEqual(store.items(matching: "").count, 0)
    }

    // The tracker's digest has to match the store's content hashes, or the
    // suppression above silently stops working.
    func testTrackerAndStoreAgreeOnTheTextHash() throws {
        let item = try XCTUnwrap(store.add(ClipboardCandidate(content: .text("same words"), sourceAppBundleID: nil, sourceAppName: nil)))
        XCTAssertEqual(item.contentHash, "text:\(SelfWriteTracker.sha256Hex("same words"))")
    }

    func testBackfillSkipsAlreadyIndexedImages() throws {
        let item = try XCTUnwrap(store.add(ClipboardCandidate(
            content: .image(textImage("done already")),
            sourceAppBundleID: nil, sourceAppName: nil
        )))
        store.applyInsights(ImageInsights(recognizedText: "done already"), to: item)
        let before = item.recognizedText

        store.backfillVisionIndex()

        XCTAssertEqual(item.recognizedText, before)
    }
}
