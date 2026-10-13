import Foundation
import PDFKit
import Vision

public enum LocalOCR {
    public static func languages() throws -> [String] {
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        return try request.supportedRecognitionLanguages()
    }
    /// Existing text pages are preserved. Image-only pages gain invisible searchable text.
    public static func recognize(_ source: PDFDocument, languages: [String] = ["en-US"], progress: Progress = Progress()) throws -> PDFDocument {
        guard !source.isLocked else { throw PDFError.locked }
        let output = try PDFOperations.extract(source, indices: Array(0..<source.pageCount))
        progress.totalUnitCount = Int64(source.pageCount)
        for index in 0..<source.pageCount {
            if progress.isCancelled { throw CancellationError() }
            try autoreleasepool {
                guard let page = source.page(at: index) else { throw PDFError.invalidDocument }
                if !(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
                let image = try RasterPDF.image(page)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
                request.recognitionLanguages = languages
                try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
                if progress.isCancelled { throw CancellationError() }
                let size = CGSize(width: CGFloat(image.width) / 2, height: CGFloat(image.height) / 2)
                let words: [(String, CGRect)] = (request.results ?? []).compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let box = observation.boundingBox
                    return (candidate.string, CGRect(x: box.minX * size.width, y: box.minY * size.height, width: box.width * size.width, height: box.height * size.height))
                }
                output.removePage(at: index)
                output.insert(try RasterPDF.page(image: image, size: size, words: words), at: index)
            }
            progress.completedUnitCount += 1
        }
        return output
    }
}
