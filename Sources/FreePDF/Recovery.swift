import AppKit
import PDFKit
import FreePDFCore

@MainActor
enum AppRecovery {
    static let store = RecoveryStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent((Bundle.main.bundleIdentifier?.hasSuffix(".preview") == true ? "FreePDFPreview" : "FreePDF") + "/Recovery", isDirectory: true))
    static func checkpoint() {
        for document in NSDocumentController.shared.documents.compactMap({ $0 as? FreePDFDocument }) {
            do {
                if document.isDocumentEdited { try store.save(PDFOperations.data(document.pdf), id: document.recoveryID) }
                else { try store.remove(id: document.recoveryID) }
            } catch { document.editor?.status.stringValue = "Recovery snapshot failed: \(error.localizedDescription)" }
        }
    }
    static func restore() {
        do {
            let files = try store.files()
            guard !files.isEmpty else { return }
            let alert = NSAlert(); alert.messageText = "Recover unsaved documents?"
            alert.informativeText = "\(files.count) saved recovery snapshots are available. Recovered documents open as new copies; encrypted documents still require their password."
            alert.addButton(withTitle: "Recover"); alert.addButton(withTitle: "Keep for later"); alert.addButton(withTitle: "Discard snapshots")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                for file in files {
                    let document = FreePDFDocument()
                    try document.read(from: Data(contentsOf: file), ofType: "com.adobe.pdf")
                    NSDocumentController.shared.addDocument(document)
                    document.makeWindowControllers()
                    guard document.editor != nil else { continue }
                    document.showWindows(); document.updateChangeCount(.changeDone)
                    try store.save(PDFOperations.data(document.pdf), id: document.recoveryID)
                    try FileManager.default.removeItem(at: file)
                }
            case .alertThirdButtonReturn:
                for file in files { try FileManager.default.removeItem(at: file) }
            default: break
            }
        } catch { Dialogs.error(error) }
    }
}
