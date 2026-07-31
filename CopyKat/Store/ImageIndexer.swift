import CoreGraphics
import Foundation
import ImageIO
import Vision

// Everything Vision can tell us about one image. Produced off the main thread;
// the store copies it onto the item afterwards.
struct ImageInsights: Equatable {
    var recognizedText: String?
    var qrPayload: String?
    var labels: [String] = []
}

// Runs OCR, barcode detection and classification on captured images, entirely
// on device. Serial by design: images arrive one at a time, and racing several
// accurate-mode OCR passes just trades latency for memory pressure.
final class ImageIndexer: Sendable {
    // More labels than this is noise, not description.
    private static let maxLabels = 6

    func insights(for imageData: Data) -> ImageInsights {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return ImageInsights() }

        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.automaticallyDetectsLanguage = true

        let barcodes = VNDetectBarcodesRequest()
        barcodes.symbologies = [.qr]

        let classify = VNClassifyImageRequest()

        let handler = VNImageRequestHandler(cgImage: image)
        try? handler.perform([text, barcodes, classify])

        var insights = ImageInsights()

        let lines = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        if !lines.isEmpty {
            insights.recognizedText = lines.joined(separator: "\n")
        }

        insights.qrPayload = (barcodes.results ?? []).compactMap(\.payloadStringValue).first

        // Precision/recall, not raw confidence: confidences are not comparable
        // across the taxonomy's classes, which is why Vision ships this filter.
        // High precision, low recall: a wrong label in search is worse than a
        // missing one.
        insights.labels = (classify.results ?? [])
            .filter { $0.hasMinimumRecall(0.01, forPrecision: 0.9) }
            .prefix(Self.maxLabels)
            .map(\.identifier)

        return insights
    }
}
