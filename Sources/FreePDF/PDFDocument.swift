import AppKit
import PDFKit
import FreePDFCore

@objc(FreePDFDocument)
final class FreePDFDocument: NSDocument {
    let recoveryID = UUID()
    var pdf = PDFDocument()
    var editor: EditorWindowController?
    var unlockPassword: String?
    override class var autosavesInPlace: Bool { false }
    override init() {
        super.init()
        hasUndoManager = true
        fileType = "com.adobe.pdf"
        if let page = try? PDFOperations.blankPage() { pdf.insert(page, at: 0) }
    }
    override func read(from data: Data, ofType typeName: String) throws {
        guard let loaded = PDFDocument(data: data) else { throw PDFError.invalidDocument }
        if loaded.isLocked, let password = unlockPassword { _ = loaded.unlock(withPassword: password) }
        pdf = loaded
        let updateUI: @MainActor () -> Void = { [weak self] in
            guard let self, self.editor != nil else { return }
            while self.pdf.isLocked {
                guard let password = Dialogs.text("Unlock PDF", message: "Enter this document’s password.", secure: true) else { self.close(); return }
                if self.pdf.unlock(withPassword: password) { self.unlockPassword = password }
                else { Dialogs.info("Incorrect password", "Please try again.") }
            }
            self.editor?.refresh()
        }
        if Thread.isMainThread { MainActor.assumeIsolated { updateUI() } }
        else { DispatchQueue.main.async { updateUI() } }
    }
    override func data(ofType typeName: String) throws -> Data { try PDFOperations.data(pdf) }
    override func makeWindowControllers() {
        while pdf.isLocked {
            guard let password = Dialogs.text("Unlock PDF", message: "Enter this document’s password.", secure: true) else { close(); return }
            if pdf.unlock(withPassword: password) { unlockPassword = password }
            else { Dialogs.info("Incorrect password", "Please try again.") }
        }
        let controller = EditorWindowController(document: self)
        editor = controller
        addWindowController(controller)
    }
    func change(_ name: String, _ operation: (PDFDocument) throws -> Void) throws {
        guard !pdf.isLocked, pdf.allowsDocumentChanges else { throw PDFError.locked }
        let before = try PDFOperations.data(pdf)
        let index = editor?.currentIndex ?? 0
        do { try operation(pdf) }
        catch { if let restored = decoded(before) { pdf = restored }; editor?.refresh(index: index); throw error }
        registerUndo(before, name: name)
        updateChangeCount(.changeDone)
        editor?.refresh(index: index)
    }
    private func decoded(_ data: Data) -> PDFDocument? {
        guard let document = PDFDocument(data: data) else { return nil }
        if document.isLocked {
            guard let password = unlockPassword, document.unlock(withPassword: password) else { return nil }
        }
        return document
    }
    private func registerUndo(_ data: Data, name: String) {
        // ponytail: full-document undo snapshots; use operation deltas if large-file memory becomes a bottleneck.
        undoManager?.registerUndo(withTarget: self) { target in
            guard let current = try? PDFOperations.data(target.pdf), let restored = target.decoded(data) else { return }
            target.registerUndo(current, name: name)
            target.pdf = restored
            target.updateChangeCount(target.undoManager?.isUndoing == true ? .changeUndone : .changeDone)
            MainActor.assumeIsolated { target.editor?.refresh() }
        }
        undoManager?.setActionName(name)
    }
    func replace(_ document: PDFDocument, name: String) throws {
        let before = try PDFOperations.data(pdf)
        registerUndo(before, name: name)
        let index = editor?.currentIndex ?? 0
        pdf = document
        updateChangeCount(.changeDone)
        editor?.refresh(index: index)
    }
    override func close() {
        do { try AppRecovery.store.remove(id: recoveryID) }
        catch { editor?.status.stringValue = "Could not remove recovery snapshot: \(error.localizedDescription)" }
        super.close()
    }
    override func printOperation(withSettings printSettings: [NSPrintInfo.AttributeKey: Any]) throws -> NSPrintOperation {
        guard pdf.allowsPrinting else { throw PDFError.locked }
        guard let operation = pdf.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) else { throw PDFError.invalidDocument }
        return operation
    }
}
