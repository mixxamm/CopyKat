import XCTest
@testable import CopyCat

final class ClipboardClassifierTests: XCTestCase {
    private func snapshot(
        types: [NSPasteboard.PasteboardType] = [.string],
        string: String? = nil,
        pngData: Data? = nil,
        fileURLs: [URL] = []
    ) -> ClipboardSnapshot {
        ClipboardSnapshot(types: types, string: string, pngData: pngData, fileURLs: fileURLs)
    }

    func testClassifiesPlainText() {
        let result = ClipboardClassifier.classify(snapshot(string: "hello"), source: nil, excludedBundleIDs: [])
        XCTAssertEqual(result?.content, .text("hello"))
    }

    func testIgnoresEmptyAndWhitespaceOnlyText() {
        XCTAssertNil(ClipboardClassifier.classify(snapshot(string: "   \n"), source: nil, excludedBundleIDs: []))
        XCTAssertNil(ClipboardClassifier.classify(snapshot(string: nil), source: nil, excludedBundleIDs: []))
    }

    func testIgnoresConcealedContent() {
        let concealed = snapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            string: "hunter2"
        )
        XCTAssertNil(ClipboardClassifier.classify(concealed, source: nil, excludedBundleIDs: []))
    }

    func testIgnoresTransientContent() {
        let transient = snapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")],
            string: "temp"
        )
        XCTAssertNil(ClipboardClassifier.classify(transient, source: nil, excludedBundleIDs: []))
    }

    func testIgnoresExcludedApps() {
        let source = RunningAppInfo(bundleID: "com.1password.1password", name: "1Password")
        let result = ClipboardClassifier.classify(
            snapshot(string: "secret"), source: source,
            excludedBundleIDs: ["com.1password.1password"]
        )
        XCTAssertNil(result)
    }

    func testPrefersFileURLOverText() {
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let result = ClipboardClassifier.classify(
            snapshot(string: "report.pdf", fileURLs: [url]), source: nil, excludedBundleIDs: []
        )
        XCTAssertEqual(result?.content, .fileURL(url))
    }

    func testPrefersImageOverText() {
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        let result = ClipboardClassifier.classify(
            snapshot(string: "img", pngData: png), source: nil, excludedBundleIDs: []
        )
        XCTAssertEqual(result?.content, .image(png))
    }

    func testCarriesSourceApp() {
        let source = RunningAppInfo(bundleID: "com.apple.Safari", name: "Safari")
        let result = ClipboardClassifier.classify(snapshot(string: "x"), source: source, excludedBundleIDs: [])
        XCTAssertEqual(result?.sourceAppBundleID, "com.apple.Safari")
        XCTAssertEqual(result?.sourceAppName, "Safari")
    }
}
