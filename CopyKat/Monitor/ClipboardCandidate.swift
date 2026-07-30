import Foundation

struct RunningAppInfo {
    let bundleID: String?
    let name: String?
}

struct ClipboardCandidate: Equatable {
    enum Content: Equatable {
        case text(String)
        case image(Data)
        case fileURL(URL)
    }

    let content: Content
    let sourceAppBundleID: String?
    let sourceAppName: String?
    var isRemote = false
    // Security-scoped bookmark for file items, so a sandboxed build can hand
    // the file back to another app when pasting.
    var fileBookmark: Data?
}
