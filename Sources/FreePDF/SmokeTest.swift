import AppKit
import PDFKit
import FreePDFCore

@MainActor
func smokeTestApplication() throws {
    guard let document = try NSDocumentController.shared.makeUntitledDocument(ofType: "com.adobe.pdf") as? FreePDFDocument else { throw NSError(domain: "FreePDFSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "document type registration"]) }
    NSDocumentController.shared.addDocument(document)
    document.makeWindowControllers()
    guard let editor = document.editor, let window = editor.window else { throw NSError(domain: "FreePDFSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "window controller creation"]) }
    guard document.windowControllers.count == 1, editor.document as? FreePDFDocument === document else {
        throw NSError(domain: "FreePDFSmoke", code: 12, userInfo: [NSLocalizedDescriptionKey: "document-window association"])
    }
    window.contentView?.layoutSubtreeIfNeeded()
    guard editor.pdfView.document?.pageCount == 1, window.contentView!.bounds.width >= 850 else { throw NSError(domain: "FreePDFSmoke", code: 3, userInfo: [NSLocalizedDescriptionKey: "initial window layout"]) }
    document.undoManager?.beginUndoGrouping()
    try document.change("Smoke test insert") { $0.insert(try PDFOperations.blankPage(), at: 1) }
    document.undoManager?.endUndoGrouping()
    guard document.pdf.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 4, userInfo: [NSLocalizedDescriptionKey: "page insertion"]) }
    document.undoManager?.undo()
    guard document.pdf.pageCount == 1 else { throw NSError(domain: "FreePDFSmoke", code: 5, userInfo: [NSLocalizedDescriptionKey: "undo"]) }
    document.undoManager?.redo()
    guard document.pdf.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 6, userInfo: [NSLocalizedDescriptionKey: "redo"]) }
    let saved = try document.data(ofType: "com.adobe.pdf")
    guard PDFDocument(data: saved)?.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 7, userInfo: [NSLocalizedDescriptionKey: "in-memory serialization"]) }
    let output = URL(fileURLWithPath: CommandLine.arguments.last!).appendingPathComponent("smoke-fixture.pdf")
    try document.writeSafely(to: output, ofType: "com.adobe.pdf", for: .saveAsOperation)
    guard PDFDocument(url: output)?.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 8, userInfo: [NSLocalizedDescriptionKey: "native safe save"]) }
    document.fileURL = output
    try document.change("Temporary extra page") { $0.insert(try PDFOperations.blankPage(), at: 2) }
    try document.revert(toContentsOf: output, ofType: "com.adobe.pdf")
    guard document.pdf.pageCount == 2, editor.pdfView.document?.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 9, userInfo: [NSLocalizedDescriptionKey: "revert model and view refresh: model=\(document.pdf.pageCount), view=\(editor.pdfView.document?.pageCount ?? -1)"]) }
    let protectedURL = output.deletingLastPathComponent().appendingPathComponent("smoke-encrypted.pdf")
    defer { try? FileManager.default.removeItem(at: protectedURL) }
    guard document.pdf.write(to: protectedURL, withOptions: [.ownerPasswordOption: "owner", .userPasswordOption: "reader"]),
          let protectedPDF = PDFDocument(url: protectedURL), protectedPDF.unlock(withPassword: "reader") else { throw NSError(domain: "FreePDFSmoke", code: 10, userInfo: [NSLocalizedDescriptionKey: "encrypted export/unlock"]) }
    document.pdf = protectedPDF; document.unlockPassword = "reader"
    document.undoManager?.beginUndoGrouping()
    try document.change("Protected insert") { $0.insert(try PDFOperations.blankPage(), at: 2) }
    document.undoManager?.endUndoGrouping()
    document.undoManager?.undo()
    guard !document.pdf.isLocked, document.pdf.pageCount == 2 else { throw NSError(domain: "FreePDFSmoke", code: 11, userInfo: [NSLocalizedDescriptionKey: "encrypted undo"]) }
    document.updateChangeCount(.changeCleared)
    document.close()
    let sample = FreePDFDocument(); sample.pdf = try makeSampleDocument()
    NSDocumentController.shared.addDocument(sample); sample.makeWindowControllers()
    guard let workspace = sample.editor else { throw PDFError.invalidDocument }
    workspace.setWorkspace(.edit)
    guard let object = workspace.contentObjects.first(where: { $0.text.contains("Edit this sentence") }) else { throw PDFError.noText }
    workspace.selectedContent = object; workspace.rebuildInspector()
    workspace.contentText.string = "A revised sentence with editable text."
    sample.undoManager?.beginUndoGrouping(); try workspace.applyTextEdit(); sample.undoManager?.endUndoGrouping()
    guard sample.pdf.page(at: 2)?.annotations.filter({ $0.type == "Widget" }).count == 3, (sample.pdf.page(at: 0)?.string ?? "").contains("A revised sentence with editable text.") else { throw PDFError.invalidDocument }
    sample.undoManager?.undo()
    guard (sample.pdf.page(at: 0)?.string ?? "").contains("Edit this sentence"), workspace.currentIndex == 0 else { throw PDFError.invalidDocument }
    sample.updateChangeCount(.changeCleared); sample.close()
    print("PASS: native window layout, document lifecycle, insert, undo, redo, PDF serialization, revert refresh, encrypted undo, workspace content editing and undo")
}
