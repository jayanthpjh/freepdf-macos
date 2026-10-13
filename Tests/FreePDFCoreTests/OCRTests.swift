import XCTest
import PDFKit
import CoreText
@testable import FreePDFCore

final class OCRTests: XCTestCase {
    func testInvisibleTextLayerSurvivesSaveAndIsSearchable() throws {
        let original = try RasterTests().fixture()
        let image = try RasterPDF.image(original.page(at: 0)!)
        let page = try RasterPDF.page(image: image, size: CGSize(width: 300, height: 200), words: [("Searchable OCR text", CGRect(x: 20, y: 100, width: 200, height: 20))])
        let document = PDFDocument(); document.insert(page, at: 0)
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(document)))
        XCTAssertTrue((reopened.string ?? "").contains("Searchable OCR text"))
        XCTAssertEqual(reopened.findString("OCR", withOptions: []).count, 1)
    }
    func testOCRPreservesExistingTextAndCancellation() throws {
        let original = try RasterTests().fixture()
        let output = try LocalOCR.recognize(original)
        XCTAssertEqual(output.string, original.string)
        let progress = Progress(totalUnitCount: 1); progress.cancel()
        XCTAssertThrowsError(try LocalOCR.recognize(original, progress: progress))
    }
    func testLocalOCRRecognizesRasterizedFixture() throws {
        let original = try RasterTests().fixture()
        let page = try RasterPDF.page(image: RasterPDF.image(original.page(at: 0)!, scale: 3), size: CGSize(width: 300, height: 200))
        let scan = PDFDocument(); scan.insert(page, at: 0)
        XCTAssertTrue((scan.string ?? "").isEmpty)
        let output = try LocalOCR.recognize(scan)
        XCTAssertTrue((output.string ?? "").uppercased().contains("SECRET"), output.string ?? "No text")
    }
}
