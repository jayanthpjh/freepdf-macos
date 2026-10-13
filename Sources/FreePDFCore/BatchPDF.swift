import Foundation
import PDFKit

public enum BatchPDF {
    public enum Operation: Sendable { case ocr, compress }
    public struct Outcome {
        public let input: URL
        public let output: URL?
        public let error: String?
    }
    /// Inputs are never overwritten. Numbered output names avoid colliding basenames.
    public static func run(inputs: [URL], folder: URL, operation: Operation, languages: [String] = ["en-US"], progress: Progress) throws -> [Outcome] {
        guard !FileManager.default.fileExists(atPath: folder.path) else { throw CocoaError(.fileWriteFileExists) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        progress.totalUnitCount = Int64(inputs.count)
        var outcomes: [Outcome] = []
        for (index, input) in inputs.enumerated() {
            if progress.isCancelled { break }
            let output = folder.appendingPathComponent("\(index + 1)-\(input.deletingPathExtension().lastPathComponent).pdf")
            do {
                try autoreleasepool {
                    guard let source = PDFDocument(url: input), !source.isLocked else { throw PDFError.locked }
                    switch operation {
                    case .ocr:
                        let child = Progress(totalUnitCount: Int64(source.pageCount))
                        progress.addChild(child, withPendingUnitCount: 1)
                        try PDFOperations.data(LocalOCR.recognize(source, languages: languages, progress: child)).write(to: output, options: .atomic)
                    case .compress:
                        guard source.write(to: output, withOptions: [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]) else { throw PDFError.invalidDocument }
                        progress.completedUnitCount += 1
                    }
                }
                outcomes.append(Outcome(input: input, output: output, error: nil))
            } catch {
                try? FileManager.default.removeItem(at: output)
                outcomes.append(Outcome(input: input, output: nil, error: error.localizedDescription))
                if progress.isCancelled { break }
            }
        }
        return outcomes
    }
}
