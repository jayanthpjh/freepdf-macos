import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    func manageAnnotations() throws {
        guard let page = pdfView.currentPage else { return }
        let annotations = page.annotations.filter { $0.type != "Widget" }
        guard !annotations.isEmpty else { Dialogs.info("No annotations", "Add a note, text box, drawing, or highlight first."); return }
        let list = annotations.enumerated().map { "\($0.offset + 1). \($0.element.type ?? "Annotation"): \($0.element.contents ?? "")" }.joined(separator: "\n")
        guard let value = Dialogs.text("Choose annotation", message: list, value: "1"), let index = Int(value), (1...annotations.count).contains(index) else { return }
        let annotation = annotations[index - 1]
        let alert = NSAlert(); alert.messageText = "Edit annotation"
        alert.addButton(withTitle: "Edit text"); alert.addButton(withTitle: "Delete"); alert.addButton(withTitle: "Cancel")
        let choice = alert.runModal()
        if choice == .alertSecondButtonReturn {
            try doc.change("Delete annotation") { _ in page.removeAnnotation(annotation) }
        } else if choice == .alertFirstButtonReturn, let text = Dialogs.text("Annotation text", value: annotation.contents ?? "") {
            try doc.change("Edit annotation") { _ in annotation.contents = text }
        }
    }
    func fillForms() throws {
        guard let page = pdfView.currentPage else { return }
        let fields = page.annotations.filter { $0.type == "Widget" && !$0.isReadOnly }
        guard !fields.isEmpty else { Dialogs.info("No editable fields", "This page has no standard editable PDF form fields. XFA forms are not supported."); return }
        let list = fields.enumerated().map { "\($0.offset + 1). \($0.element.fieldName ?? "Unnamed"): \($0.element.widgetStringValue ?? "")" }.joined(separator: "\n")
        guard let value = Dialogs.text("Choose form field", message: list, value: "1"), let index = Int(value), (1...fields.count).contains(index) else { return }
        let field = fields[index - 1]
        if field.widgetFieldType == .button {
            guard field.widgetControlType != .pushButtonControl else { Dialogs.info("Push button", "Executing PDF button actions is disabled."); return }
            try doc.change("Toggle form field") { _ in field.buttonWidgetState = field.buttonWidgetState == .onState ? .offState : .onState }
        } else {
            let options = field.choices?.joined(separator: ", ") ?? ""
            guard let text = Dialogs.text(field.fieldName ?? "Form field", message: options.isEmpty ? "Enter a field value." : "Available values: \(options)", value: field.widgetStringValue ?? "") else { return }
            if field.widgetFieldType == .choice, let choices = field.choices, !choices.contains(text) { throw PDFError.invalidDocument }
            try doc.change("Fill form field") { _ in field.widgetStringValue = text }
        }
    }
    func createForm() throws {
        guard let page = pdfView.currentPage, let name = Dialogs.text("New text form field", message: "Choose a unique field name. The field will be placed at the selected text, or at the center of the page."), !name.isEmpty else { return }
        for index in 0..<doc.pdf.pageCount {
            if doc.pdf.page(at: index)?.annotations.contains(where: { $0.fieldName == name }) == true { Dialogs.info("Name already used", "Choose another field name."); return }
        }
        let box = page.bounds(for: .cropBox)
        let rect = pdfView.currentSelection?.bounds(for: page) ?? CGRect(x: box.midX - 110, y: box.midY, width: 220, height: 30)
        let field = PDFAnnotation(bounds: rect, forType: .widget, withProperties: nil)
        field.widgetFieldType = .text; field.fieldName = name; field.widgetStringValue = ""
        field.font = .systemFont(ofSize: textSize); field.backgroundColor = .white
        let border = PDFBorder(); border.lineWidth = 1; field.border = border
        try doc.change("Create form field") { _ in page.addAnnotation(field) }
    }
    func decorate(_ command: String) throws {
        var text = ""
        if command != "numbers" {
            guard let value = Dialogs.text(command.capitalized, value: command == "stamp" ? "APPROVED" : "DRAFT") else { return }; text = value
        }
        try doc.change("Add \(command)") { pdf in
            let indices = command == "stamp" ? [currentIndex] : Array(0..<pdf.pageCount)
            for index in indices {
                guard let page = pdf.page(at: index) else { continue }
                let box = page.bounds(for: .cropBox)
                let rect = command == "numbers" ? CGRect(x: box.midX - 50, y: box.minY + 18, width: 100, height: 24) : CGRect(x: box.minX + 40, y: command == "stamp" ? box.maxY - 80 : box.midY, width: max(100, box.width - 80), height: 55)
                let annotation = PDFAnnotation(bounds: rect, forType: .freeText, withProperties: nil)
                annotation.contents = command == "numbers" ? "\(index + 1) / \(pdf.pageCount)" : text
                annotation.font = .boldSystemFont(ofSize: command == "numbers" ? 12 : 32)
                annotation.fontColor = command == "watermark" ? selectedColor.withAlphaComponent(0.25) : selectedColor
                annotation.color = .clear; annotation.alignment = .center
                page.addAnnotation(annotation)
            }
        }
    }
    func crop() throws {
        guard let page = pdfView.currentPage, let input = Dialogs.text("Crop page margins", message: "Enter left,bottom,right,top margins in PDF points (72 points = 1 inch).", value: "20,20,20,20") else { return }
        let values = input.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == 4, values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw PDFError.invalidPages }
        let box = page.bounds(for: .cropBox)
        let rect = CGRect(x: box.minX + values[0], y: box.minY + values[1], width: box.width - values[0] - values[2], height: box.height - values[1] - values[3])
        guard rect.width > 0, rect.height > 0 else { throw PDFError.invalidPages }
        try doc.change("Crop page") { _ in page.setBounds(rect, for: .cropBox) }
    }
    func bookmark() throws {
        guard let page = pdfView.currentPage, let title = Dialogs.text("Bookmark title", value: "Page \(currentIndex + 1)"), !title.isEmpty else { return }
        try doc.change("Add bookmark") { pdf in
            let root = pdf.outlineRoot ?? PDFOutline()
            let item = PDFOutline(); item.label = title
            item.destination = PDFDestination(page: page, at: CGPoint(x: page.bounds(for: .cropBox).minX, y: page.bounds(for: .cropBox).maxY))
            root.insertChild(item, at: root.numberOfChildren); pdf.outlineRoot = root
        }
    }
    func showOutline() {
        var entries: [(String, PDFDestination)] = []
        func visit(_ node: PDFOutline, depth: Int) {
            if let destination = node.destination { entries.append((String(repeating: "  ", count: min(depth, 10)) + (node.label ?? "Bookmark"), destination)) }
            guard depth < 100 else { return }
            for index in 0..<node.numberOfChildren { if let child = node.child(at: index) { visit(child, depth: depth + 1) } }
        }
        if let root = doc.pdf.outlineRoot { visit(root, depth: 0) }
        guard !entries.isEmpty else { Dialogs.info("No bookmarks", "Add a bookmark using the Pages menu."); return }
        let list = entries.enumerated().map { "\($0.offset + 1). \($0.element.0)" }.joined(separator: "\n")
        if let input = Dialogs.text("Document outline", message: list, value: "1"), let index = Int(input), (1...entries.count).contains(index) { pdfView.go(to: entries[index - 1].1) }
    }
    func showProperties() {
        let attributes = doc.pdf.documentAttributes ?? [:]
        let title = attributes[PDFDocumentAttribute.titleAttribute] as? String ?? ""
        let author = attributes[PDFDocumentAttribute.authorAttribute] as? String ?? ""
        Dialogs.info("Document properties", "Pages: \(doc.pdf.pageCount)\nTitle: \(title)\nAuthor: \(author)\nEncrypted: \(doc.pdf.isEncrypted ? "Yes" : "No")\nAll processing is local.")
    }
    func signature() throws {
        guard let page = pdfView.currentPage, let url = Dialogs.open(types: [.image]).first, let image = NSImage(contentsOf: url), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        guard Dialogs.confirm("Place signature image", "Places a visible signature mark near the bottom of this page and flattens the page. This is not a certificate-based digital signature.") else { return }
        let base = try RasterPDF.image(page)
        guard let context = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PDFError.invalidDocument }
        context.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        let width = min(CGFloat(base.width) * 0.4, 400)
        let height = min(width * CGFloat(cgImage.height) / CGFloat(cgImage.width), 160)
        context.draw(cgImage, in: CGRect(x: 80, y: 80, width: width, height: height))
        guard let combined = context.makeImage() else { throw PDFError.invalidDocument }
        let replacement = try RasterPDF.page(image: combined, size: CGSize(width: CGFloat(base.width) / 2, height: CGFloat(base.height) / 2))
        let index = currentIndex
        try doc.change("Place signature") { pdf in pdf.removePage(at: index); pdf.insert(replacement, at: index) }
    }
}
