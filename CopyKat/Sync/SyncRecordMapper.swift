import CloudKit
import Foundation

// Items to records and back. The record name is the content hash, so the same
// text copied on two devices lands on one record instead of two.
enum SyncRecordMapper {
    static let recordType = "ClipboardItem"
    static let zoneID = CKRecordZone.ID(zoneName: "ClipboardHistory")

    static func recordID(for contentHash: String) -> CKRecord.ID {
        CKRecord.ID(recordName: contentHash, zoneID: zoneID)
    }

    static func record(for item: ClipboardItem, imageFileURL: URL?) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: recordID(for: item.contentHash))
        record["kind"] = item.kind.rawValue
        record["text"] = item.text
        record["createdAt"] = item.createdAt
        record["isPinned"] = item.isPinned ? 1 : 0
        record["sourceAppName"] = item.sourceAppName
        record["imageWidth"] = item.imageWidth
        record["imageHeight"] = item.imageHeight
        // Vision output travels along, so the phone searches screenshots
        // without redoing the work.
        record["recognizedText"] = item.recognizedText
        record["qrPayload"] = item.qrPayload
        record["imageLabels"] = item.imageLabels
        if let imageFileURL {
            record["image"] = CKAsset(fileURL: imageFileURL)
        }
        return record
    }

    // Upserts into the local store; the content hash decides new versus known.
    @MainActor
    static func apply(_ record: CKRecord, to store: HistoryStore, imageStore: ImageStore) {
        guard record.recordType == recordType,
              let kindRaw = record["kind"] as? String,
              let kind = ClipboardItemKind(rawValue: kindRaw)
        else { return }
        let contentHash = record.recordID.recordName

        let insights = ImageInsights(
            recognizedText: record["recognizedText"] as? String,
            qrPayload: record["qrPayload"] as? String,
            labels: (record["imageLabels"] as? String)?.split(separator: " ").map(String.init) ?? []
        )

        if let existing = store.item(withContentHash: contentHash) {
            // Content is immutable per hash; only the pin can differ, and a pin
            // anywhere wins over an unpin nowhere.
            let pinned = (record["isPinned"] as? Int ?? 0) == 1
            if pinned != existing.isPinned, pinned {
                store.togglePin(existing)
            }
            return
        }

        var imageData: Data?
        if kind == .image, let asset = record["image"] as? CKAsset, let url = asset.fileURL {
            imageData = try? Data(contentsOf: url)
        }

        store.insertSynced(
            contentHash: contentHash,
            kind: kind,
            text: record["text"] as? String,
            imageData: imageData,
            createdAt: record["createdAt"] as? Date ?? .now,
            isPinned: (record["isPinned"] as? Int ?? 0) == 1,
            sourceAppName: record["sourceAppName"] as? String,
            insights: insights
        )
    }
}
