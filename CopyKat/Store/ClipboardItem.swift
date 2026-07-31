import Foundation
import SwiftData

enum ClipboardItemKind: String, Codable {
    case text
    case image
    case fileURL
}

@Model
final class ClipboardItem {
    // Every attribute carries a default: CloudKit-backed SwiftData stores
    // refuse a model without them, and the iPhone app is on its way.
    var kind: ClipboardItemKind = ClipboardItemKind.text
    var text: String?
    var imageFilename: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var contentHash: String = ""
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt: Date = Date.now
    var isPinned: Bool = false
    var pinShortcutID: String?
    var isRemote: Bool = false
    var fileBookmark: Data?

    // Filled in by the Vision indexer for images, so search can see into them.
    // Defaults keep the migration additive and the model CloudKit-ready.
    var recognizedText: String? = nil
    var qrPayload: String? = nil
    // Space-joined English classification identifiers ("document receipt cat").
    var imageLabels: String? = nil
    var visionIndexed: Bool = false

    // What ⌥-Enter pastes: the text in the image, or failing that the QR link.
    var pastableInsightText: String? {
        recognizedText ?? qrPayload
    }

    init(
        kind: ClipboardItemKind,
        text: String? = nil,
        imageFilename: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        contentHash: String,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.kind = kind
        self.text = text
        self.imageFilename = imageFilename
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.contentHash = contentHash
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}
