import SwiftUI

struct PreviewPane: View {
    let item: ClipboardItem?
    let imageStore: ImageStore

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
            Text(item.createdAt, format: .relative(presentation: .named))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 32)
    }
}
