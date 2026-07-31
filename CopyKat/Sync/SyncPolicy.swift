import Foundation

// What the user allowed into iCloud. Everything here is opt-in: the master
// switch is off until they flip it, and each kind has its own toggle because
// "sync my snippets" and "upload every screenshot" are different promises.
struct SyncPolicy: Equatable {
    enum Scope: String, CaseIterable {
        case everything
        case pinned
        // Pinned items plus the newest fifty: enough to be useful on the
        // phone without mirroring years of history.
        case recent
    }

    var enabled = false
    var text = true
    var files = true
    var images = false
    var scope: Scope = .everything

    static let recentLimit = 50

    static func current() -> SyncPolicy {
        SyncPolicy(
            enabled: AppSettings.cloudSyncEnabled,
            text: AppSettings.cloudSyncText,
            files: AppSettings.cloudSyncFiles,
            images: AppSettings.cloudSyncImages,
            scope: Scope(rawValue: AppSettings.cloudSyncScope) ?? .everything
        )
    }

    // The exclusions the Mac applies while recording (ignored apps, concealed
    // passwords) never reach the store, so everything here is already past
    // that gate. This filter only applies the user's sync choices.
    func qualifyingItems(in newestFirst: [ClipboardItem]) -> [ClipboardItem] {
        guard enabled else { return [] }
        let kindAllowed: (ClipboardItem) -> Bool = { item in
            switch item.kind {
            case .text: self.text
            case .fileURL: self.files
            case .image: self.images
            }
        }
        switch scope {
        case .everything:
            return newestFirst.filter(kindAllowed)
        case .pinned:
            return newestFirst.filter { $0.isPinned && kindAllowed($0) }
        case .recent:
            let pinned = newestFirst.filter { $0.isPinned && kindAllowed($0) }
            let recent = newestFirst
                .filter { !$0.isPinned && kindAllowed($0) }
                .prefix(Self.recentLimit)
            return pinned + recent
        }
    }
}
