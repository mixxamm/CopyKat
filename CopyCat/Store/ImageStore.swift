import AppKit
import CryptoKit

struct SavedImage: Equatable {
    let filename: String
    let width: Int
    let height: Int
    let hash: String
}

final class ImageStore {
    enum Error: Swift.Error {
        case notPNG
    }

    let directory: URL
    private let thumbnails = NSCache<NSString, NSImage>()

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(pngData: Data) throws -> SavedImage {
        guard let rep = NSBitmapImageRep(data: pngData) else { throw Error.notPNG }
        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        let filename = "\(hash).png"
        let url = imageURL(for: filename)
        if !FileManager.default.fileExists(atPath: url.path) {
            try pngData.write(to: url, options: .atomic)
        }
        return SavedImage(filename: filename, width: rep.pixelsWide, height: rep.pixelsHigh, hash: hash)
    }

    func imageURL(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func loadImage(named filename: String) -> NSImage? {
        NSImage(contentsOf: imageURL(for: filename))
    }

    func thumbnail(for filename: String, maxDimension: CGFloat) -> NSImage? {
        let key = "\(filename)-\(Int(maxDimension))" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let image = loadImage(named: filename), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumb = NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
        thumbnails.setObject(thumb, forKey: key)
        return thumb
    }

    func delete(named filename: String) {
        try? FileManager.default.removeItem(at: imageURL(for: filename))
    }

    func existingFilenames() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".png") })
    }
}
