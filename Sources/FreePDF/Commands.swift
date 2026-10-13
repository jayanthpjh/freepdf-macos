import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    static func commandCatalog(_ group: String) -> [(String, String)] {
        switch group {
        case "annotateMenu": return [("Highlight selection", "highlight"), ("Underline selection", "underline"), ("Strike through selection", "strike"), ("Manage annotations…", "annotations"), ("Signature image…", "signature"), ("Fill form fields…", "forms"), ("Create text field…", "createForm")]
        case "pagesMenu": return [("Go to page…", "goto"), ("Rotate right", "rotate"), ("Insert blank page", "blank"), ("Insert PDF / merge…", "merge"), ("Insert images…", "images"), ("Delete pages…", "delete"), ("Reorder pages…", "reorder"), ("Move page…", "move"), ("Crop current page…", "crop"), ("Document outline…", "outline"), ("Bookmark current page…", "bookmark")]
        case "toolsMenu": return [("Recognize text (OCR)…", "ocr"), ("Batch OCR (English)…", "batchOCR"), ("Batch compress PDFs…", "batchCompress"), ("Page numbers", "numbers"), ("Watermark…", "watermark"), ("Stamp…", "stamp"), ("Apply raster redactions…", "applyRedactions"), ("Clear redaction marks", "clearRedactions"), ("Compare document text…", "compare"), ("Document properties…", "properties"), ("Single page", "single"), ("Continuous pages", "continuous"), ("Two pages", "twoUp")]
        default: return [("Extract pages…", "extract"), ("Split into individual PDFs…", "split"), ("Current page as PNG…", "png"), ("Plain text…", "textExport"), ("Rich text…", "rtf"), ("Flattened PDF…", "flatten"), ("Compressed PDF…", "compress"), ("Password-protected PDF…", "encrypt")]
        }
    }
    func commands(for group: String) -> [(String, String)] { Self.commandCatalog(group) }
    func perform(_ command: String) {
        safely {
            switch command {
            case "highlight", "underline", "strike": try markup(command)
            case "rotate": try doc.change("Rotate page") { $0.page(at: currentIndex)?.rotation += 90 }
            case "blank": try doc.change("Insert page") { $0.insert(try PDFOperations.blankPage(), at: currentIndex + 1) }
            case "goto":
                if let text = Dialogs.text("Go to page", value: "\(currentIndex + 1)"), let page = Int(text), page > 0, page <= doc.pdf.pageCount { pdfView.go(to: doc.pdf.page(at: page - 1)!) }
            case "merge": try mergeFiles()
            case "images": try insertImages()
            case "delete", "extract", "reorder": try pageOperation(command)
            case "move": try movePage()
            case "annotations": try manageAnnotations()
            case "forms": try fillForms()
            case "createForm": try createForm()
            case "signature": try signature()
            case "numbers", "watermark", "stamp": try decorate(command)
            case "png", "textExport", "rtf", "flatten", "compress", "encrypt", "split": try export(command)
            case "single": pdfView.displayMode = .singlePage
            case "continuous": pdfView.displayMode = .singlePageContinuous
            case "twoUp": pdfView.displayMode = .twoUpContinuous
            case "crop": try crop()
            case "bookmark": try bookmark()
            case "outline": showOutline()
            case "properties": showProperties()
            case "clearRedactions": pendingRegions = [:]; refresh()
            case "applyRedactions": redact()
            case "compare": try compare()
            case "ocr": ocr()
            case "batchOCR": try batch(.ocr)
            case "batchCompress": try batch(.compress)
            default: break
            }
        }
    }
    func markup(_ command: String) throws {
        guard let selection = pdfView.currentSelection, !(selection.string ?? "").isEmpty else { throw PDFError.noText }
        let type: PDFAnnotationSubtype = command == "underline" ? .underline : command == "strike" ? .strikeOut : .highlight
        try doc.change("\(command.capitalized) text") { _ in
            for line in selection.selectionsByLine() {
                for page in line.pages {
                    let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: type, withProperties: nil)
                    annotation.color = command == "highlight" ? selectedColor.withAlphaComponent(0.35) : selectedColor
                    page.addAnnotation(annotation)
                }
            }
        }
    }
    func addRegion(_ page: PDFPage, _ rect: CGRect, _ points: [CGPoint]) {
        safely {
            let tool = pdfView.tool
            if tool == .redact {
                pendingRegions[doc.pdf.index(for: page), default: []].append(rect)
                pdfView.redactionOverlay.needsDisplay = true
                status.stringValue = "Redaction area marked. Use Apply redactions to create a sanitized copy."
                return
            }
            if tool == .replace {
                guard let text = Dialogs.text("Replace area", message: "Creates a flattened copy of the whole document. The selected area is erased and replaced with this text. Fonts and layout are not matched automatically.") else { return }
                rasterCopy(regions: [doc.pdf.index(for: page): [rect]], replacement: text)
                return
            }
            var content = ""
            if tool == .text || tool == .note {
                guard let text = Dialogs.text(tool.rawValue, message: "Text for the selected area") else { return }; content = text
            }
            let type: PDFAnnotationSubtype
            switch tool { case .note: type = .text; case .rectangle: type = .square; case .oval: type = .circle; case .ink: type = .ink; default: type = .freeText }
            let annotation = PDFAnnotation(bounds: rect, forType: type, withProperties: nil)
            annotation.color = selectedColor; annotation.contents = content
            annotation.font = .systemFont(ofSize: textSize); annotation.fontColor = selectedColor
            if tool == .text { annotation.color = .clear }
            let border = PDFBorder(); border.lineWidth = 2; annotation.border = border
            if tool == .ink {
                let path = NSBezierPath()
                if let first = points.first { path.move(to: NSPoint(x: first.x - rect.minX, y: first.y - rect.minY)) }
                for point in points.dropFirst() { path.line(to: NSPoint(x: point.x - rect.minX, y: point.y - rect.minY)) }
                annotation.add(path)
            }
            try doc.change("Add \(tool.rawValue.lowercased())") { _ in page.addAnnotation(annotation) }
        }
    }
    func mergeFiles() throws {
        let urls = Dialogs.open(types: [.pdf], multiple: true)
        guard !urls.isEmpty else { return }
        let incoming = try urls.map { url -> PDFDocument in
            guard let pdf = PDFDocument(url: url), !pdf.isLocked else { throw PDFError.locked }
            return try PDFOperations.extract(pdf, indices: Array(0..<pdf.pageCount))
        }
        try doc.change("Merge PDFs") { pdf in
            var insertion = currentIndex + 1
            for other in incoming { for index in 0..<other.pageCount { pdf.insert(other.page(at: index)!, at: insertion); insertion += 1 } }
        }
    }
    func insertImages() throws {
        let urls = Dialogs.open(types: [.image], multiple: true)
        guard !urls.isEmpty else { return }
        let pages = try urls.map { url -> PDFPage in
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { throw PDFError.invalidDocument }
            return page
        }
        try doc.change("Insert images") { pdf in for (offset, page) in pages.enumerated() { pdf.insert(page, at: currentIndex + 1 + offset) } }
    }
    func pageOperation(_ action: String) throws {
        let defaultValue = action == "reorder" ? "1-\(doc.pdf.pageCount)" : "\(currentIndex + 1)"
        guard let text = Dialogs.text("\(action.capitalized) pages", message: "Page numbers and ranges, for example 1-3,5.", value: defaultValue) else { return }
        let indices = try PDFOperations.pageIndices(text, count: doc.pdf.pageCount)
        if action == "extract" {
            guard let url = Dialogs.save(name: "Extracted.pdf", type: .pdf) else { return }
            try PDFOperations.data(PDFOperations.extract(doc.pdf, indices: indices)).write(to: url, options: .atomic)
        } else if action == "delete" {
            guard indices.count < doc.pdf.pageCount else { throw PDFError.invalidPages }
            try doc.change("Delete pages") { pdf in for index in indices.sorted(by: >) { pdf.removePage(at: index) } }
            pendingRegions = [:]
        } else {
            guard indices.count == doc.pdf.pageCount else { throw PDFError.invalidPages }
            try doc.replace(PDFOperations.extract(doc.pdf, indices: indices), name: "Reorder pages")
            pendingRegions = [:]
        }
    }
    func movePage() throws {
        guard let value = Dialogs.text("Move current page to position", value: "\(currentIndex + 1)"), let destination = Int(value), destination > 0, destination <= doc.pdf.pageCount else { return }
        let index = currentIndex
        try doc.change("Move page") { pdf in let page = pdf.page(at: index)!; pdf.removePage(at: index); pdf.insert(page, at: destination - 1) }
        pendingRegions = [:]
    }
}
