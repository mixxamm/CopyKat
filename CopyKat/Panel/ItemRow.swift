import SwiftUI

struct ItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let imageStore: ImageStore
    var showsSourceApp = true
    var quickPasteBadge: Int?

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
            VStack(alignment: .leading, spacing: 2) {
                content
                subtitle
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if let badge = quickPasteBadge {
                Text(verbatim: "⌘\(badge)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : .clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if item.kind == .image, let filename = item.imageFilename,
           let thumb = imageStore.thumbnail(for: filename, maxDimension: 36) {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else if item.isRemote {
            Image(systemName: "iphone")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        } else if showsSourceApp, let icon = AppIconProvider.icon(forBundleID: item.sourceAppBundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: item.kind == .fileURL ? "doc" : "text.alignleft")
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "")
                .lineLimit(2)
        case .fileURL:
            Text((item.text as NSString?)?.lastPathComponent ?? "")
                .lineLimit(1)
        case .image:
            Text("Image")
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: some View {
        HStack(spacing: 4) {
            if item.kind == .image, let width = item.imageWidth, let height = item.imageHeight {
                Text(verbatim: "\(width) × \(height)")
            }
            if item.isRemote {
                Text("Other device")
            } else if showsSourceApp, item.kind != .image, let appName = item.sourceAppName {
                Text(appName)
            }
            Text(item.createdAt, format: .relative(presentation: .named))
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
