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
                insights(for: item)
                Divider()
                source(for: item)
            }
        }
    }

    // One quiet row of what Vision saw in an image: the QR link, else the
    // classification labels, else the first line it read, plus the ⌥↩ hint
    // whenever there is text to paste. A plain unremarkable image shows nothing.
    private func insightsLine(for item: ClipboardItem) -> (icon: String, text: String)? {
        if let qr = item.qrPayload { return ("qrcode", qr) }
        if let labels = item.imageLabels { return ("tag", labels) }
        if let line = item.recognizedText?.split(separator: "\n").first {
            return ("text.viewfinder", String(line))
        }
        return nil
    }

    @ViewBuilder
    private func insights(for item: ClipboardItem) -> some View {
        if let line = insightsLine(for: item) {
            Divider()
            HStack(spacing: 7) {
                Image(systemName: line.icon)
                    .foregroundStyle(.secondary)
                Text(line.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if item.pastableInsightText != nil {
                    Text("⌥↩ pastes text")
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                }
            }
            .font(.caption)
            .padding(.horizontal, 14)
            .frame(height: 26)
        }
    }

    private func source(for item: ClipboardItem) -> some View {
        // Both flanks take an equal share of the row, which pins the counter to
        // the middle. Letting it sit next to the timestamp made it slide about
        // as that text grew from "now" to "46 minutes ago".
        HStack(spacing: 7) {
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
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let position, total > 0 {
                Text("\(position) of \(total)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize()
            }

            Text(item.createdAt, format: .relative(presentation: .named))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 32)
    }
}
