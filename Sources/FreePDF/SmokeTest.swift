import AppKit
import PDFKit
import FreePDFCore

@MainActor
func smokeTestApplication() throws {
    guard let document = try NSDocumentController.shared.makeUntitledDocument(ofType: "com.adobe.pdf") as? FreePDFDocument else { throw PDFError.invalidDocument }
    NSDocumentController.shared.addDocument(document)
    document.makeWindowControllers()
    guard let editor = document.editor, let window = editor.window else { throw PDFError.invalidDocument }
    window.contentView?.layoutSubtreeIfNeeded()
    guard editor.pdfView.document?.pageCount == 1, window.contentView!.bounds.width >= 850 else { throw PDFError.invalidDocument }
    document.undoManager?.beginUndoGrouping()
    try document.change("Smoke test insert") { $0.insert(try PDFOperations.blankPage(), at: 1) }
    document.undoManager?.endUndoGrouping()
    guard document.pdf.pageCount == 2 else { throw PDFError.invalidDocument }
    document.undoManager?.undo()
    guard document.pdf.pageCount == 1 else { throw PDFError.invalidDocument }
    document.undoManager?.redo()
    guard document.pdf.pageCount == 2 else { throw PDFError.invalidDocument }
    let saved = try document.data(ofType: "com.adobe.pdf")
    guard PDFDocument(data: saved)?.pageCount == 2 else { throw PDFError.invalidDocument }
    let output = URL(fileURLWithPath: CommandLine.arguments.last!).appendingPathComponent("smoke-fixture.pdf")
    try document.writeSafely(to: output, ofType: "com.adobe.pdf", for: .saveAsOperation)
    guard PDFDocument(url: output)?.pageCount == 2 else { throw PDFError.invalidDocument }
    let protectedURL = output.deletingLastPathComponent().appendingPathComponent("smoke-encrypted.pdf")
    defer { try? FileManager.default.removeItem(at: protectedURL) }
    guard document.pdf.write(to: protectedURL, withOptions: [.ownerPasswordOption: "owner", .userPasswordOption: "reader"]),
          let protectedPDF = PDFDocument(url: protectedURL), protectedPDF.unlock(withPassword: "reader") else { throw PDFError.invalidDocument }
    document.pdf = protectedPDF; document.unlockPassword = "reader"
    document.undoManager?.beginUndoGrouping()
    try document.change("Protected insert") { $0.insert(try PDFOperations.blankPage(), at: 2) }
    document.undoManager?.endUndoGrouping()
    document.undoManager?.undo()
    guard !document.pdf.isLocked, document.pdf.pageCount == 2 else { throw PDFError.invalidDocument }
    document.updateChangeCount(.changeCleared)
    document.close()
    print("PASS: native window layout, document lifecycle, insert, undo, redo, PDF serialization, encrypted undo")
}
