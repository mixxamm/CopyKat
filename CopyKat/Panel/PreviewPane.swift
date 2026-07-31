import SwiftUI

struct PreviewPane: View {
    let item: ClipboardItem?
    let imageStore: ImageStore
    // Where the highlight sits. With the list hidden there is nothing else to
    // tell you how far into the history you have cycled.
    var position: Int?
    var total: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch item?.kind {
                case .image:
                    if let filename = item?.imageFilename, let image = imageStore.loadImage(named: filename) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                    }
                case .text, .fileURL:
                    ScrollView {
                        Text(item?.text ?? "")
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(12)
                    }
                case nil:
                    ContentUnavailableView("No selection", systemImage: "doc.on.clipboard")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Where the item came from lives here rather than on every row: one
            // quiet line instead of a label repeated down the whole list.
            if let item {
                Divider()
                source(for: item)
            }
        }
    }

    private func source(for item: ClipboardItem) -> some View {
        HStack(spacing: 7) {
            if item.isRemote {
                Image(systemName: "iphone")
                    .foregroundStyle(.secondary)
                Text("Other device")
            } else if let icon = AppIconProvider.icon(forBundleID: item.sourceAppBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 15, height: 15)
                Text(item.sourceAppName ?? "")
            }

            if item.kind == .image, let width = item.imageWidth, let height = item.imageHeight {
                Text(verbatim: "\(width) × \(height)")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            if let position, total > 0 {
                Text("\(position) of \(total)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Text(item.createdAt, format: .relative(presentation: .named))
                .foregroundStyle(.secondary)
                // Two numbers side by side read as one without a wider gap.
                .padding(.leading, 6)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 32)
    }
}
