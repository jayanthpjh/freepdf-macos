import XCTest
import PDFKit
@testable import FreePDFCore

final class RecoveryTests: XCTestCase {
    func testRecoveryRoundTripAndRemovalPreserveExactBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecoveryStore(directory: directory); let id = UUID()
        let document = PDFDocument(); document.insert(try PDFOperations.blankPage(), at: 0)
        let bytes = try PDFOperations.data(document)
        XCTAssertEqual(try store.files(), [])
        try store.save(bytes, id: id)
        let file = try XCTUnwrap(store.files().first)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        try store.save(bytes, id: id)
        XCTAssertEqual(try store.files().count, 1)
        try store.remove(id: id)
        XCTAssertEqual(try store.files(), [])
    }
}
