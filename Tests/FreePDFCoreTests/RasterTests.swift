import CoreText

import XCTest
import AppKit
import PDFKit
@testable import FreePDFCore

final class RasterTests: XCTestCase {
    func fixture() throws -> PDFDocument {
        let buffer = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 300, height: 200)
        let context = try XCTUnwrap(CGContext(consumer: CGDataConsumer(data: buffer)!, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(box)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "SECRET visible", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 20, nil)]) as CFAttributedString)
        context.textPosition = CGPoint(x: 20, y: 100)
        CTLineDraw(line, context)
        context.endPDFPage(); context.closePDF()
        return try XCTUnwrap(PDFDocument(data: buffer as Data))
    }
    func testRasterRedactionRemovesTextMetadataAndAnnotations() throws {
        let source = try fixture()
        source.documentAttributes = [PDFDocumentAttribute.titleAttribute: "SECRET metadata"]
        let note = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 20, height: 20), forType: .text, withProperties: nil)
        note.contents = "SECRET note"
        source.page(at: 0)!.addAnnotation(note)
        let result = try RasterPDF.redact(source, regions: [0: [CGRect(x: 15, y: 95, width: 180, height: 35)]], scale: 1)
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(result)))
        XCTAssertTrue((reopened.string ?? "").isEmpty)
        XCTAssertEqual(reopened.page(at: 0)?.annotations.count, 0)
        XCTAssertNil(reopened.documentAttributes?[PDFDocumentAttribute.titleAttribute])
        XCTAssertTrue(source.string!.contains("SECRET"))
        let image = try RasterPDF.image(reopened.page(at: 0)!, scale: 1)
        XCTAssertEqual(image.width, 300)
    }
    func testRejectsOutOfBoundsAndExcessiveRendering() throws {
        let source = try fixture()
        XCTAssertThrowsError(try RasterPDF.redact(source, regions: [5: [.zero]]))
        XCTAssertThrowsError(try RasterPDF.image(source.page(at: 0)!, scale: 10000))
    }
}
