import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    func redact() {
        guard !pendingRegions.isEmpty else { Dialogs.info("No redaction areas", "Choose Redact area, drag over the content to remove, then apply redactions."); return }
        guard Dialogs.confirm("Create redacted copy", "Rebuilds every page as an image and removes source text, forms, bookmarks, attachments, and metadata. The marked areas become black. The new copy is unencrypted. The original stays open. Inspect the new PDF before sharing it.", button: "Create copy") else { return }
        rasterCopy(regions: pendingRegions)
    }
    func rasterCopy(regions: [Int: [CGRect]], replacement: String? = nil) {
        runJob(name: replacement == nil ? "Redacted copy" : "Replaced-area copy") { source, progress in
            try RasterPDF.redact(source, regions: regions, replacement: replacement, progress: progress)
        }
    }
    func ocr() {
        do {
            let languages = try LocalOCR.languages()
            guard let input = Dialogs.text("OCR language", message: "On-device recognition. Creates an unencrypted new copy. Existing text pages are preserved; scanned pages are flattened with a searchable text layer.\nSupported: \(languages.joined(separator: ", "))", value: "en-US") else { return }
            let chosen = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !chosen.isEmpty, chosen.allSatisfy(languages.contains) else { Dialogs.info("Unsupported language", "Choose language codes from the supported list."); return }
            runJob(name: "Searchable copy") { source, progress in try LocalOCR.recognize(source, languages: chosen, progress: progress) }
        } catch { Dialogs.error(error) }
    }
    func runJob(name: String, operation: @escaping (PDFDocument, Progress) throws -> PDFDocument) {
        guard job == nil else { return }
        do {
            let data = try PDFOperations.data(doc.pdf)
            let password = doc.unlockPassword
            let progress = Progress(totalUnitCount: Int64(doc.pdf.pageCount)); job = progress
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateStatus() }
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result: Result<Data, Error> = Result {
                    guard let source = PDFDocument(data: data) else { throw PDFError.invalidDocument }
                    if source.isLocked {
                        guard let password, source.unlock(withPassword: password) else { throw PDFError.locked }
                    }
                    return try PDFOperations.data(operation(source, progress))
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.progressTimer?.invalidate(); self.progressTimer = nil
                    self.job = nil; self.updateStatus()
                    if progress.isCancelled { return }
                    switch result {
                    case .success(let data):
                        guard let pdf = PDFDocument(data: data) else { Dialogs.error(PDFError.invalidDocument); return }
                        let document = FreePDFDocument(); document.pdf = pdf
                        NSDocumentController.shared.addDocument(document)
                        document.makeWindowControllers(); document.showWindows()
                        document.updateChangeCount(.changeDone)
                        document.editor?.window?.title = name
                    case .failure(let error): Dialogs.error(error)
                    }
                }
            }
        } catch { Dialogs.error(error) }
    }
}
