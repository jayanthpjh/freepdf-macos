import XCTest
import PDFKit
import CoreText
import AppKit
@testable import FreePDFCore

final class ContentEditingTests: XCTestCase {
    func testExistingTextIsReplacedInSavedPDFWithoutRasterization() throws {
        let source = try RasterTests().fixture()
        let bytes = try PDFOperations.data(source)
        let objects = try ContentEditing.objects(in: bytes, page: 0)
        let object = try XCTUnwrap(objects.first { $0.kind == .text && $0.text.contains("SECRET") })
        let edited = try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible")
        let reopened = try XCTUnwrap(PDFDocument(data: edited))
        XCTAssertTrue((reopened.string ?? "").contains("PUBLIC visible"), reopened.string ?? "")
        XCTAssertFalse((reopened.string ?? "").contains("SECRET"))
        XCTAssertTrue(source.string!.contains("SECRET"))
        XCTAssertEqual(try ContentEditing.objects(in: edited, page: 0).filter { $0.kind == .text }.count, objects.filter { $0.kind == .text }.count)
        let rendering = try RasterPDF.image(reopened.page(at: 0)!, scale: 1)
        let renderedData = try XCTUnwrap(rendering.dataProvider?.data)
        let pixels = CFDataGetBytePtr(renderedData)!
        let corner = 10 * rendering.bytesPerRow + 10 * 4
        for channel in 0..<3 { XCTAssertGreaterThan(pixels[corner + channel], 240, "White background changed after content editing") }
    }
    func testFontSizeUsesPagePointsAfterSave() throws {
        let bytes = try PDFOperations.data(RasterTests().fixture())
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.kind == .text })
        XCTAssertGreaterThan(object.fontSize, 5)
        let result = try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible", fontSize: 18)
        let after = try XCTUnwrap(ContentEditing.objects(in: result, page: 0).first { $0.kind == .text })
        XCTAssertEqual(after.fontSize, 18, accuracy: 0.1)
    }
    func testContentChangesPreserveCalibratedPathColorsAndOtherText() throws {
        let buffer = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 300, height: 200)
        let context = try XCTUnwrap(CGContext(consumer: CGDataConsumer(data: buffer)!, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor); context.fill(box)
        context.setFillColor(NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.8, alpha: 1).cgColor)
        context.fill(CGRect(x: 200, y: 20, width: 50, height: 50))
        context.setStrokeColor(NSColor.systemTeal.cgColor); context.setLineWidth(4)
        context.move(to: CGPoint(x: 20, y: 180)); context.addLine(to: CGPoint(x: 280, y: 180)); context.strokePath()
        for (text, y) in [("SECRET visible", 100.0), ("UNCHANGED text", 150.0)] {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 20, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): NSColor.black.cgColor]) as CFAttributedString)
            context.textPosition = CGPoint(x: 20, y: y); CTLineDraw(line, context)
        }
        context.endPDFPage(); context.closePDF()
        let bytes = buffer as Data
        let source = try XCTUnwrap(PDFDocument(data: bytes))
        let original = try RasterPDF.image(source.page(at: 0)!, scale: 1)
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.text.contains("SECRET") })
        let outputs = [
            try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible"),
            try ContentEditing.moveObject(in: bytes, page: 0, object: object.id, to: object.bounds.offsetBy(dx: 10, dy: 0)),
            try ContentEditing.deleteObject(in: bytes, page: 0, object: object.id)
        ]
        let originalData = try XCTUnwrap(original.dataProvider?.data)
        let originalPixels = CFDataGetBytePtr(originalData)!
        for output in outputs {
            let reopened = try XCTUnwrap(PDFDocument(data: output))
            XCTAssertTrue((reopened.string ?? "").contains("UNCHANGED text"))
            let rendered = try RasterPDF.image(reopened.page(at: 0)!, scale: 1)
            let renderedData = try XCTUnwrap(rendered.dataProvider?.data)
            let pixels = CFDataGetBytePtr(renderedData)!
            // Compare untouched white background, colored fill, teal stroke,
            // and the black text region. Quartz bitmap coordinates are top-down.
            for (x, y) in [(10, 10), (220, 150), (100, 20)] {
                for channel in 0..<3 {
                    let before = Int(originalPixels[y * original.bytesPerRow + x * 4 + channel])
                    let after = Int(pixels[y * rendered.bytesPerRow + x * 4 + channel])
                    XCTAssertEqual(after, before, accuracy: 3)
                }
            }
            for y in 30..<50 { for x in 20..<180 {
                for channel in 0..<3 {
                    let offset = y * rendered.bytesPerRow + x * 4 + channel
                    XCTAssertEqual(Int(pixels[offset]), Int(originalPixels[offset]), accuracy: 3)
                }
            } }
        }
    }
    func testMoveAndDeleteSavedTextObject() throws {
        let bytes = try PDFOperations.data(RasterTests().fixture())
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.kind == .text })
        let moved = try ContentEditing.moveObject(in: bytes, page: 0, object: object.id, to: object.bounds.offsetBy(dx: 20, dy: 10))
        let after = try XCTUnwrap(ContentEditing.objects(in: moved, page: 0).first { $0.kind == .text })
        XCTAssertEqual(after.bounds.minX, object.bounds.minX + 20, accuracy: 0.2)
        XCTAssertEqual(after.bounds.minY, object.bounds.minY + 10, accuracy: 0.2)
        let deleted = try ContentEditing.deleteObject(in: moved, page: 0, object: after.id)
        XCTAssertFalse((PDFDocument(data: deleted)?.string ?? "").contains("SECRET"))
        XCTAssertEqual(try ContentEditing.objects(in: deleted, page: 0).count, 0)
    }
    func testOriginalSubsetFontRejectsMissingGlyphs() throws {
        let bytes = try PDFOperations.data(RasterTests().fixture())
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.kind == .text })
        XCTAssertThrowsError(try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible", font: .original))
        XCTAssertTrue(PDFDocument(data: bytes)!.string!.contains("SECRET"))
    }

    func testDuplicatePageTextCannotHideMissingEditedGlyphs() throws {
        let buffer = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 300, height: 200)
        let context = try XCTUnwrap(CGContext(consumer: CGDataConsumer(data: buffer)!, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        for (text, font, y) in [("SECRET visible", "Helvetica", 100.0), ("PUBLIC visible", "Courier", 60.0)] {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName(font as CFString, 20, nil)]) as CFAttributedString)
            context.textPosition = CGPoint(x: 20, y: y)
            CTLineDraw(line, context)
        }
        context.endPDFPage(); context.closePDF()
        let bytes = buffer as Data
        XCTAssertTrue((PDFDocument(data: bytes)?.string ?? "").contains("PUBLIC visible"))
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.text.contains("SECRET") })
        XCTAssertThrowsError(try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible", font: .original)) { error in
            XCTAssertTrue(error is ContentEditing.EditError)
        }
        XCTAssertTrue((PDFDocument(data: bytes)?.string ?? "").contains("SECRET visible"))
    }

    func testImageReplacementKeepsTextAndImageBounds() throws {
        func image(_ color: CGColor) throws -> CGImage {
            let context = try XCTUnwrap(CGContext(data: nil, width: 80, height: 60, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: 80, height: 60)); return try XCTUnwrap(context.makeImage())
        }
        let document = PDFDocument(); document.insert(try RasterPDF.page(image: image(CGColor(red: 0, green: 1, blue: 0, alpha: 1)), size: CGSize(width: 300, height: 200), words: [("Retained label", CGRect(x: 20, y: 140, width: 120, height: 20))]), at: 0)
        let bytes = try PDFOperations.data(document)
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0).first { $0.kind == .image })
        let result = try ContentEditing.replaceImage(in: bytes, page: 0, object: object.id, image: image(CGColor(red: 1, green: 0, blue: 0, alpha: 1)))
        let reopened = try XCTUnwrap(PDFDocument(data: result))
        XCTAssertTrue((reopened.string ?? "").contains("Retained label"))
        let after = try XCTUnwrap(ContentEditing.objects(in: result, page: 0).first { $0.kind == .image })
        XCTAssertEqual(after.bounds, object.bounds)
        let rendered = try RasterPDF.image(reopened.page(at: 0)!, scale: 1)
        let data = try XCTUnwrap(rendered.dataProvider?.data)
        let pixels = CFDataGetBytePtr(data)!
        let pixel = 50 * rendered.bytesPerRow + 50 * 4
        // PDF rendering applies display color management; compare channel dominance
        // and the original green image rather than assuming exact device values.
        XCTAssertGreaterThan(pixels[pixel], 200)
        XCTAssertGreaterThan(Int(pixels[pixel]) - Int(pixels[pixel + 1]), 150)
        let original = try RasterPDF.image(document.page(at: 0)!, scale: 1)
        let originalData = try XCTUnwrap(original.dataProvider?.data)
        let originalPixels = CFDataGetBytePtr(originalData)!
        let originalPixel = 50 * original.bytesPerRow + 50 * 4
        XCTAssertGreaterThan(Int(originalPixels[originalPixel + 1]) - Int(originalPixels[originalPixel]), 150)
    }
    func testTextEditPreservesEncryptedOutput() throws {
        let source = try RasterTests().fixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(source.write(to: url, withOptions: [.ownerPasswordOption: "owner", .userPasswordOption: "reader"]))
        let bytes = try Data(contentsOf: url)
        let object = try XCTUnwrap(ContentEditing.objects(in: bytes, page: 0, password: "reader").first { $0.kind == .text })
        let edited = try ContentEditing.replaceText(in: bytes, page: 0, object: object.id, text: "PUBLIC visible", password: "reader")
        let reopened = try XCTUnwrap(PDFDocument(data: edited))
        XCTAssertTrue(reopened.isEncrypted); XCTAssertTrue(reopened.isLocked)
        XCTAssertTrue(reopened.unlock(withPassword: "reader")); XCTAssertTrue((reopened.string ?? "").contains("PUBLIC visible"))
    }

}
