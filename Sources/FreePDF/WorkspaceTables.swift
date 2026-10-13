import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard document is FreePDFDocument else { return 0 }
        if tableView === pageList { return doc.pdf.pageCount }
        return workspace == .edit ? contentObjects.count : pageAnnotations.count
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        if tableView === pageList {
            guard let page = doc.pdf.page(at: row) else { return nil }
            let image = NSImageView(); image.image = page.thumbnail(of: NSSize(width: 154, height: 130), for: .cropBox); image.imageScaling = .scaleProportionallyUpOrDown
            let caption = label("Page \(row + 1)", size: 12); caption.alignment = .center
            for view in [image, caption] { view.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(view) }
            NSLayoutConstraint.activate([image.centerXAnchor.constraint(equalTo: cell.centerXAnchor), image.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6), image.widthAnchor.constraint(equalToConstant: 154), image.heightAnchor.constraint(equalToConstant: 130), caption.topAnchor.constraint(equalTo: image.bottomAnchor, constant: 6), caption.centerXAnchor.constraint(equalTo: cell.centerXAnchor)])
            cell.imageView = image; cell.textField = caption
        } else {
            let text: String
            if workspace == .edit, contentObjects.indices.contains(row) {
                let object = contentObjects[row]
                text = object.kind == .text ? "Text · \(object.text)" : "Image · \(Int(object.bounds.width)) × \(Int(object.bounds.height)) pt"
            } else if pageAnnotations.indices.contains(row) {
                let item = pageAnnotations[row]
                text = workspace == .forms ? "\(item.fieldName ?? "Unnamed field")\n\(item.widgetStringValue ?? "")" : "\(item.type ?? "Comment") · \(item.contents ?? "")"
            } else { return nil }
            let field = label(String(text.prefix(180)), size: 12); field.maximumNumberOfLines = 2; field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(field)
            NSLayoutConstraint.activate([field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6), field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6), field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
            cell.textField = field
        }
        return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !updatingInspector, let table = notification.object as? NSTableView, document is FreePDFDocument else { return }
        if table === pageList {
            if let page = doc.pdf.page(at: table.selectedRow) { pdfView.go(to: page) }
        } else {
            let row = table.selectedRow
            if workspace == .edit { selectedContent = contentObjects.indices.contains(row) ? contentObjects[row] : nil }
            else { selectedAnnotation = pageAnnotations.indices.contains(row) ? pageAnnotations[row] : nil }
            updatingInspector = true; rebuildInspector(); updatingInspector = false
            pdfView.redactionOverlay.needsDisplay = true
        }
    }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView === pageList, job == nil else { return nil }
        let item = NSPasteboardItem(); item.setString(String(row), forType: Self.pagePasteboardType); return item
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard tableView === pageList, info.draggingSource as? NSTableView === pageList, job == nil, operation == .above, row >= 0, row <= doc.pdf.pageCount else { return [] }
        return .move
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard tableView === pageList, info.draggingSource as? NSTableView === pageList, job == nil else { return false }
        let indices = (info.draggingPasteboard.pasteboardItems ?? []).compactMap { $0.string(forType: Self.pagePasteboardType).flatMap(Int.init) }
        do { try doc.change("Reorder pages") { try PDFOperations.movePages($0, indices: indices, before: row) }; return true }
        catch { Dialogs.error(error); return false }
    }
}
