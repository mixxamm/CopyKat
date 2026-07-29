import SwiftUI

struct PreviewPane: View {
    let item: ClipboardItem?
    let imageStore: ImageStore

    var body: some View {
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
    }
}
