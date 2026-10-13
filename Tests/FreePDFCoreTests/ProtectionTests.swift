import XCTest
import PDFKit
@testable import FreePDFCore

final class ProtectionTests: XCTestCase {
    func testEncryptedExportRequiresCorrectPassword() throws {
        let document = PDFDocument(); document.insert(try PDFOperations.blankPage(), at: 0)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(document.write(to: url, withOptions: [.ownerPasswordOption: "owner-test", .userPasswordOption: "reader-test"]))
        let protected = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertTrue(protected.isLocked)
        XCTAssertFalse(protected.unlock(withPassword: "wrong"))
        XCTAssertTrue(protected.unlock(withPassword: "reader-test"))
        XCTAssertEqual(protected.pageCount, 1)
    }
    func testUnlockedSerializationDoesNotSilentlyDropEncryption() throws {
        let document = PDFDocument(); document.insert(try PDFOperations.blankPage(), at: 0)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(document.write(to: url, withOptions: [.ownerPasswordOption: "owner", .userPasswordOption: "reader"]))
        let protected = try XCTUnwrap(PDFDocument(url: url)); XCTAssertTrue(protected.unlock(withPassword: "reader"))
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(protected)))
        XCTAssertTrue(reopened.isEncrypted)
        XCTAssertTrue(reopened.isLocked)
    }
    func testFormFieldValuesSurviveSaving() throws {
        let document = PDFDocument(); let page = try PDFOperations.blankPage()
        let field = PDFAnnotation(bounds: CGRect(x: 40, y: 60, width: 200, height: 30), forType: .widget, withProperties: nil)
        field.widgetFieldType = .text; field.fieldName = "FullName"; field.widgetStringValue = "Ada Lovelace"
        page.addAnnotation(field); document.insert(page, at: 0)
        let reopened = try XCTUnwrap(PDFDocument(data: PDFOperations.data(document)))
        XCTAssertEqual(reopened.page(at: 0)?.annotations.first?.widgetStringValue, "Ada Lovelace")
    }
}
