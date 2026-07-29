import Foundation
import SwiftData

enum ClipboardItemKind: String, Codable {
    case text
    case image
    case fileURL
}

@Model
final class ClipboardItem {
    var kind: ClipboardItemKind
    var text: String?
    var imageFilename: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var contentHash: String
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var createdAt: Date
    var isPinned: Bool

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
