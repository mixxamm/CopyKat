#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
import CoreGraphics
import CryptoKit
import ImageIO

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
    private let thumbnails = NSCache<NSString, PlatformImage>()

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func save(pngData: Data) throws -> SavedImage {
        // ImageIO rather than NSBitmapImageRep: the same code has to size the
        // image on both platforms.
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw Error.notPNG }
        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        let filename = "\(hash).png"
        let url = imageURL(for: filename)
        if !FileManager.default.fileExists(atPath: url.path) {
            try pngData.write(to: url, options: .atomic)
        }
        return SavedImage(filename: filename, width: width, height: height, hash: hash)
    }

    func imageURL(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    func loadImage(named filename: String) -> PlatformImage? {
        #if canImport(AppKit)
        return NSImage(contentsOf: imageURL(for: filename))
        #else
        return UIImage(contentsOfFile: imageURL(for: filename).path)
        #endif
    }

    func thumbnail(for filename: String, maxDimension: CGFloat) -> PlatformImage? {
        let key = "\(filename)-\(Int(maxDimension))" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        // Downsampling through ImageIO never decodes the full bitmap, and works
        // identically on both platforms.
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension) * 2,
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(imageURL(for: filename) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        else { return nil }
        // Twice the pixels for Retina, but the reported size stays in points.
        let downscale = min(maxDimension / CGFloat(cg.width), maxDimension / CGFloat(cg.height), 1)
        let points = CGSize(width: CGFloat(cg.width) * downscale, height: CGFloat(cg.height) * downscale)
        #if canImport(AppKit)
        let thumb = NSImage(cgImage: cg, size: points)
        #else
        let thumb = UIImage(cgImage: cg, scale: CGFloat(cg.width) / points.width, orientation: .up)
        #endif
        thumbnails.setObject(thumb, forKey: key)
        return thumb
    }

    func delete(named filename: String) {
        try? FileManager.default.removeItem(at: imageURL(for: filename))
    }

    func totalBytes() -> Int64 {
        existingFilenames().reduce(into: Int64(0)) { total, name in
            let path = imageURL(for: name).path
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int64
            total += size ?? 0
        }
    }

    func existingFilenames() -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.filter { $0.hasSuffix(".png") })
    }
}
