import XCTest
import PDFKit
@testable import FreePDFCore

final class PDFOperationsTests: XCTestCase {
    func testPageRangesPreserveRequestedOrderAndRejectInvalidInput() throws {
        XCTAssertEqual(try PDFOperations.pageIndices("3, 1-2", count: 4), [2, 0, 1])
        for invalid in ["", "0", "5", "3-1", "1,1", "1,", "x", "1-2-3", "-1"] {
            XCTAssertThrowsError(try PDFOperations.pageIndices(invalid, count: 4), invalid)
        }
    }
    func testExtractionPreservesRotationAndAnnotationsAfterRoundTrip() throws {
        let source = PDFDocument()
        let page = try PDFOperations.blankPage()
        page.rotation = 90
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 40, width: 100, height: 40), forType: .freeText, withProperties: nil)
        annotation.contents = "Review comment"
        page.addAnnotation(annotation)
        source.insert(page, at: 0)
        source.insert(try PDFOperations.blankPage(), at: 1)
        let output = try PDFOperations.extract(source, indices: [1, 0])
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(output)))
        XCTAssertEqual(reopened.pageCount, 2)
        XCTAssertEqual(reopened.page(at: 1)?.rotation, 90)
        XCTAssertEqual(reopened.page(at: 1)?.annotations.first?.contents, "Review comment")
        XCTAssertEqual(source.pageCount, 2)
        XCTAssertThrowsError(try PDFOperations.extract(source, indices: [-1]))
        XCTAssertThrowsError(try PDFOperations.extract(source, indices: []))
    }
    func testMultiplePageMovePreservesOrderAndRoundTrips() throws {
        let document = PDFDocument()
        for rotation in [0, 90, 180, 270] { let page = try PDFOperations.blankPage(); page.rotation = rotation; document.insert(page, at: document.pageCount) }
        try PDFOperations.movePages(document, indices: [0, 2], before: 4)
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(document)))
        XCTAssertEqual((0..<4).map { reopened.page(at: $0)!.rotation }, [90, 270, 0, 180])
        XCTAssertThrowsError(try PDFOperations.movePages(document, indices: [1, 1], before: 0))
    }

}
