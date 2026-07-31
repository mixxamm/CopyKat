import CloudKit
import XCTest
@testable import CopyKat

final class SyncPolicyTests: XCTestCase {
    private func item(_ text: String, kind: ClipboardItemKind = .text, pinned: Bool = false) -> ClipboardItem {
        let item = ClipboardItem(kind: kind, text: text, contentHash: "\(kind.rawValue):\(text)", isPinned: pinned)
        return item
    }

    func testDisabledPolicySyncsNothing() {
        var policy = SyncPolicy()
        policy.enabled = false
        XCTAssertTrue(policy.qualifyingItems(in: [item("a"), item("b", pinned: true)]).isEmpty)
    }

    func testKindTogglesGateEachKindSeparately() {
        var policy = SyncPolicy(enabled: true)
        policy.text = true
        policy.files = false
        policy.images = false
        let all = [
            item("note"),
            item("/tmp/report.pdf", kind: .fileURL),
            item("shot", kind: .image),
        ]
        XCTAssertEqual(policy.qualifyingItems(in: all).map(\.text), ["note"])

        policy.images = true
        XCTAssertEqual(Set(policy.qualifyingItems(in: all).compactMap(\.text)), ["note", "shot"])
    }

    func testPinnedScopeDropsEverythingUnpinned() {
        var policy = SyncPolicy(enabled: true)
        policy.scope = .pinned
        let result = policy.qualifyingItems(in: [item("loose"), item("kept", pinned: true)])
        XCTAssertEqual(result.map(\.text), ["kept"])
    }

    func testRecentScopeKeepsPinsAndTheNewestFifty() {
        var policy = SyncPolicy(enabled: true)
        policy.scope = .recent
        var items = (0..<80).map { item("item \($0)") }
        items.append(item("old favourite", pinned: true))
        let result = policy.qualifyingItems(in: items)
        XCTAssertEqual(result.count, SyncPolicy.recentLimit + 1)
        XCTAssertTrue(result.contains { $0.text == "old favourite" })
        XCTAssertTrue(result.contains { $0.text == "item 0" })
        XCTAssertFalse(result.contains { $0.text == "item 79" })
    }

    func testRecordRoundTripCarriesEverything() {
        let source = item("round trip", pinned: true)
        source.sourceAppName = "Safari"
        source.recognizedText = nil
        let record = SyncRecordMapper.record(for: source, imageFileURL: nil)

        XCTAssertEqual(record.recordID.recordName, source.contentHash)
        XCTAssertEqual(record["kind"] as? String, "text")
        XCTAssertEqual(record["text"] as? String, "round trip")
        XCTAssertEqual(record["isPinned"] as? Int, 1)
        XCTAssertEqual(record["sourceAppName"] as? String, "Safari")
    }

    func testImageRecordCarriesAnAsset() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let source = item("img", kind: .image)
        let record = SyncRecordMapper.record(for: source, imageFileURL: file)
        let asset = try XCTUnwrap(record["image"] as? CKAsset)
        XCTAssertEqual(asset.fileURL, file)
    }
}
