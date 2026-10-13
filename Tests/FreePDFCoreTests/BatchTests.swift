import XCTest
import PDFKit
@testable import FreePDFCore

final class BatchTests: XCTestCase {
    func testBatchKeepsOriginalAndReportsIndividualFailures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("Original.pdf")
        let document = PDFDocument(); document.insert(try PDFOperations.blankPage(), at: 0)
        let bytes = try PDFOperations.data(document); try bytes.write(to: input)
        let folder = root.appendingPathComponent("Batch")
        let result = try BatchPDF.run(inputs: [input, root.appendingPathComponent("Missing.pdf")], folder: folder, operation: .compress, progress: Progress())
        XCTAssertEqual(result.count, 2)
        XCTAssertNotNil(result[0].output); XCTAssertNil(result[0].error)
        XCTAssertNil(result[1].output); XCTAssertNotNil(result[1].error)
        XCTAssertEqual(try Data(contentsOf: input), bytes)
        XCTAssertThrowsError(try BatchPDF.run(inputs: [input], folder: folder, operation: .compress, progress: Progress()))
    }
}
