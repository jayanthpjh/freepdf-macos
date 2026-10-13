import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    func export(_ command: String) throws {
        switch command {
        case "textExport", "rtf":
            guard let text = doc.pdf.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PDFError.noText }
            let rich = command == "rtf"
            guard let url = Dialogs.save(name: rich ? "Document.rtf" : "Document.txt", type: rich ? .rtf : .plainText) else { return }
            let data: Data
            if rich {
                let string = NSAttributedString(string: text)
                data = try string.data(from: NSRange(location: 0, length: string.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            } else { data = Data(text.utf8) }
            try data.write(to: url, options: .atomic)
        case "png":
            guard let page = pdfView.currentPage, let url = Dialogs.save(name: "Page-\(currentIndex + 1).png", type: .png) else { return }
            let bitmap = NSBitmapImageRep(cgImage: try RasterPDF.image(page))
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw PDFError.invalidDocument }
            try data.write(to: url, options: .atomic)
        case "split":
            let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Choose output folder"
            guard panel.runModal() == .OK, let parent = panel.url else { return }
            let folder = parent.appendingPathComponent("FreePDF-split-\(UUID().uuidString.prefix(8))", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            do {
                for index in 0..<doc.pdf.pageCount {
                    let extracted = try PDFOperations.extract(doc.pdf, indices: [index])
                    try PDFOperations.data(extracted).write(to: folder.appendingPathComponent("Page-\(index + 1).pdf"), options: .atomic)
                }
                NSWorkspace.shared.open(folder)
            } catch { try? FileManager.default.removeItem(at: folder); throw error }
        default:
            var options: [PDFDocumentWriteOption: Any] = [:]
            var name = "Exported.pdf"
            if command == "flatten" { options[.burnInAnnotationsOption] = true; name = "Flattened.pdf" }
            if command == "compress" {
                guard Dialogs.confirm("Compress a copy", "Optimizes images for screen viewing. This can reduce image quality; savings depend on the source PDF.") else { return }
                options[.saveImagesAsJPEGOption] = true; options[.optimizeImagesForScreenOption] = true; name = "Compressed.pdf"
            }
            if command == "encrypt" {
                guard let password = Dialogs.text("PDF open password", message: "Choose a password. This creates a new encrypted copy.", secure: true), !password.isEmpty else { return }
                guard let repeated = Dialogs.text("Confirm password", secure: true), repeated == password else { Dialogs.info("Passwords differ", "The export was cancelled."); return }
                options[.userPasswordOption] = password; options[.ownerPasswordOption] = UUID().uuidString
                name = "Protected.pdf"
            }
            guard let url = Dialogs.save(name: name, type: .pdf) else { return }
            let temporary = url.deletingLastPathComponent().appendingPathComponent(".freepdf-\(UUID().uuidString).pdf")
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard let copy = PDFDocument(data: try PDFOperations.data(doc.pdf)) else { throw PDFError.invalidDocument }
            if copy.isLocked {
                guard let password = doc.unlockPassword, copy.unlock(withPassword: password) else { throw PDFError.locked }
            }
            guard copy.write(to: temporary, withOptions: options) else { throw PDFError.invalidDocument }
            let data = try Data(contentsOf: temporary)
            try data.write(to: url, options: .atomic)
        }
    }
    func compare() throws {
        guard let url = Dialogs.open(types: [.pdf]).first, let other = PDFDocument(url: url), !other.isLocked else { return }
        let old = doc.pdf.string ?? "", new = other.string ?? ""
        guard !old.isEmpty || !new.isEmpty else { throw PDFError.noText }
        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)
        // ponytail: line comparison ignores visual/layout changes; a visual diff is a separate roadmap item.
        let diff = newLines.difference(from: oldLines)
        let lines = diff.map { change -> String in
            switch change {
            case let .remove(offset, element, _): return "− Line \(offset + 1): \(element)"
            case let .insert(offset, element, _): return "+ Line \(offset + 1): \(element)"
            }
        }
        guard let output = Dialogs.save(name: "Text-comparison.txt", type: .plainText) else { return }
        let report = "FreePDF text comparison\nSource pages: \(doc.pdf.pageCount); compared pages: \(other.pageCount)\nVisual changes are not compared.\n\n" + (lines.isEmpty ? "No differences in extracted text." : lines.joined(separator: "\n"))
        try Data(report.utf8).write(to: output, options: .atomic)
        NSWorkspace.shared.open(output)
    }
}
