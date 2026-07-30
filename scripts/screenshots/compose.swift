import AppKit
import Foundation

// Builds one App Store screenshot: crops the window out of a full screen
// capture, places it on the brand gradient and draws the caption above it.
// AppKit does the text drawing so Arabic, Hindi and CJK shape correctly, which
// PIL and friends get wrong.

let out = CommandLine.arguments
guard out.count >= 8 else {
    FileHandle.standardError.write("usage: compose.swift <capture.png> <x> <y> <w> <h> <caption> <out.png>\n".data(using: .utf8)!)
    exit(1)
}

let capturePath = out[1]
let winX = Double(out[2])!, winY = Double(out[3])!
let winW = Double(out[4])!, winH = Double(out[5])!
let caption = out[6].replacingOccurrences(of: "\\n", with: "\n")
let outPath = out[7]
let rtl = out.count > 8 && out[8] == "rtl"
let showKeys = out.count > 9 && out[9] == "keys"

let canvasW = 2880.0, canvasH = 1800.0
let captionTop = 130.0
let windowTop = showKeys ? 690.0 : 520.0
let bottomMargin = 90.0

guard let capture = NSImage(contentsOfFile: capturePath),
      let captureRep = capture.representations.first as? NSBitmapImageRep else {
    FileHandle.standardError.write("cannot read \(capturePath)\n".data(using: .utf8)!)
    exit(1)
}

// The capture is in pixels, the window rect in points.
let scale = Double(captureRep.pixelsWide) / 2056.0
let cropRect = NSRect(
    x: winX * scale, y: winY * scale,
    width: winW * scale, height: winH * scale
)

guard let cg = captureRep.cgImage?.cropping(to: cropRect) else {
    FileHandle.standardError.write("crop failed\n".data(using: .utf8)!)
    exit(1)
}
let window = NSImage(cgImage: cg, size: NSSize(width: cropRect.width, height: cropRect.height))

let target = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvasW), pixelsHigh: Int(canvasH),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
target.size = NSSize(width: canvasW, height: canvasH)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 1.00, green: 0.69, blue: 0.29, alpha: 1),
    ending: NSColor(calibratedRed: 0.91, green: 0.33, blue: 0.13, alpha: 1)
)!
gradient.draw(in: NSRect(x: 0, y: 0, width: canvasW, height: canvasH), angle: -90)

// Window, scaled to the space under the caption, centred.
let available = canvasH - windowTop - bottomMargin
let fit = min(available / cropRect.height, (canvasW * 0.82) / cropRect.width)
let drawW = cropRect.width * fit
let drawH = cropRect.height * fit
let drawX = (canvasW - drawW) / 2
let drawY = canvasH - windowTop - drawH

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedRed: 0.35, green: 0.12, blue: 0.02, alpha: 0.45)
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 46
NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
window.draw(in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH))
NSGraphicsContext.current?.restoreGraphicsState()

// Caption.
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.lineSpacing = 18
paragraph.baseWritingDirection = rtl ? .rightToLeft : .leftToRight

var size = 112.0
var attributed: NSAttributedString
repeat {
    let font = NSFont.systemFont(ofSize: size, weight: .bold)
    attributed = NSAttributedString(string: caption, attributes: [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ])
    size -= 4
} while attributed.size().width > canvasW * 0.86 && size > 60

let textHeight = attributed.boundingRect(
    with: NSSize(width: canvasW * 0.86, height: 400),
    options: [.usesLineFragmentOrigin]
).height
attributed.draw(with: NSRect(
    x: canvasW * 0.07,
    y: canvasH - captionTop - textHeight,
    width: canvasW * 0.86,
    height: textHeight
), options: [.usesLineFragmentOrigin])

// Keycaps for the hotkey, the same three the website shows.
if showKeys {
    let caps = ["\u{21E7}", "\u{2318}", "V"]
    let capSize = 132.0
    let gap = 26.0
    let totalWidth = Double(caps.count) * capSize + Double(caps.count - 1) * gap
    var x = (canvasW - totalWidth) / 2
    let y = canvasH - windowTop + 92

    for cap in caps {
        let face = NSRect(x: x, y: y, width: capSize, height: capSize)
        let path = NSBezierPath(roundedRect: face, xRadius: 28, yRadius: 28)

        NSColor(calibratedRed: 0.35, green: 0.12, blue: 0.02, alpha: 0.35).setFill()
        NSBezierPath(roundedRect: face.offsetBy(dx: 0, dy: -9), xRadius: 28, yRadius: 28).fill()

        NSColor(calibratedRed: 1.0, green: 0.97, blue: 0.93, alpha: 1).setFill()
        path.fill()

        let glyph = NSAttributedString(string: cap, attributes: [
            .font: NSFont.systemFont(ofSize: 62, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: 0.17, green: 0.10, blue: 0.06, alpha: 1),
        ])
        let gs = glyph.size()
        glyph.draw(at: NSPoint(x: x + (capSize - gs.width) / 2, y: y + (capSize - gs.height) / 2))
        x += capSize + gap
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let data = target.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
