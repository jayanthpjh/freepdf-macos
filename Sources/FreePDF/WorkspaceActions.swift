import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    @objc func workspaceChanged() { setWorkspace(WorkspaceMode.allCases[modeControl.selectedSegment]) }
    func setWorkspace(_ mode: WorkspaceMode) {
        workspace = mode; selectedContent = nil; selectedAnnotation = nil
        modeControl.selectedSegment = WorkspaceMode.allCases.firstIndex(of: mode) ?? 0
        for button in modeButtons { button.state = button.command == "mode:\(mode.rawValue)" ? .on : .off; button.contentTintColor = button.state == .on ? .systemTeal : .labelColor }
        pdfView.tool = mode == .edit ? .editContent : .select
        toolPicker.selectItem(withTitle: pdfView.tool.rawValue)
        if mode == .pages { sidebarSwitch.selectedSegment = 1; sidebarChanged() }
        reloadInspector(); updateStatus()
    }
    @objc func sidebarChanged() {
        toolsScroll.isHidden = sidebarSwitch.selectedSegment == 1
        pageScroll.isHidden = sidebarSwitch.selectedSegment == 0
        workspaceSplit.adjustSubviews()
    }
    @objc func toggleInspector() { inspectorScroll.isHidden.toggle(); workspaceSplit.adjustSubviews() }
    @objc func saveCopy() { doc.saveAs(nil) }
    @objc func jumpToPage() {
        guard let number = Int(pageNumber.stringValue), number > 0, number <= doc.pdf.pageCount, let page = doc.pdf.page(at: number - 1) else { NSSound.beep(); updateStatus(); return }
        pdfView.go(to: page)
    }
    @objc func workspaceAction(_ sender: WorkspaceButton) {
        let command = sender.command
        if command.hasPrefix("mode:"), let mode = WorkspaceMode(rawValue: String(command.dropFirst(5))) { setWorkspace(mode); return }
        if command.hasPrefix("tool:"), let tool = CanvasTool(rawValue: String(command.dropFirst(5))) {
            if workspace != .annotate { setWorkspace(.annotate) }
            pdfView.tool = tool; toolPicker.selectItem(withTitle: tool.rawValue); updateStatus(); return
        }
        safely {
            switch command {
            case "showPages": sidebarSwitch.selectedSegment = 1; sidebarChanged()
            case "applyText": try applyTextEdit()
            case "replaceImage": try replaceSelectedImage()
            case "applyBounds": try applyContentBounds()
            case "deleteContent": try deleteSelectedContent()
            case "updateComment": try changeSelectedAnnotation(delete: false)
            case "deleteAnnotation": try changeSelectedAnnotation(delete: true)
            case "applyField", "applyChoice", "toggleField": try updateSelectedField(command)
            case "rotateSelected", "deleteSelected", "extractSelected": try selectedPageOperation(command)
            case "recognizeNow":
                let language = ocrLanguage.selectedItem?.representedObject as? String ?? "en-US"
                runJob(name: "Searchable copy") { source, progress in try LocalOCR.recognize(source, languages: [language], progress: progress) }
            default: perform(command)
            }
        }
    }
    func editedDocument(_ bytes: Data, name: String) throws {
        guard doc.pdf.allowsDocumentChanges, let pdf = PDFDocument(data: bytes) else { throw PDFError.invalidDocument }
        if pdf.isLocked { guard let password = doc.unlockPassword, pdf.unlock(withPassword: password) else { throw PDFError.locked } }
        guard !doc.pdf.isEncrypted || pdf.isEncrypted else { throw PDFError.invalidDocument }
        try doc.replace(pdf, name: name)
    }
    func applyTextEdit() throws {
        guard let object = selectedContent, object.kind == .text, let size = Double(objectSize.stringValue) else { return }
        let font = ContentEditing.Font(rawValue: contentFont.titleOfSelectedItem ?? "Helvetica") ?? .helvetica
        let result = try ContentEditing.replaceText(in: PDFOperations.data(doc.pdf), page: currentIndex, object: object.id, text: contentText.string, fontSize: size, font: font, password: doc.unlockPassword)
        try editedDocument(result, name: "Edit PDF text")
    }
    func replaceSelectedImage() throws {
        guard let object = selectedContent, object.kind == .image, let url = Dialogs.open(types: [.image]).first,
              let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        try editedDocument(ContentEditing.replaceImage(in: PDFOperations.data(doc.pdf), page: currentIndex, object: object.id, image: image, password: doc.unlockPassword), name: "Replace PDF image")
    }
    func applyContentBounds() throws {
        guard let object = selectedContent else { return }
        let values = rectFields.compactMap { Double($0.stringValue) }
        guard values.count == 4 else { throw PDFError.invalidPages }
        let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        try editedDocument(ContentEditing.moveObject(in: PDFOperations.data(doc.pdf), page: currentIndex, object: object.id, to: rect, password: doc.unlockPassword), name: "Move PDF content")
    }
    func deleteSelectedContent() throws {
        guard let object = selectedContent else { return }
        try editedDocument(ContentEditing.deleteObject(in: PDFOperations.data(doc.pdf), page: currentIndex, object: object.id, password: doc.unlockPassword), name: "Delete PDF content")
        selectedContent = nil; reloadInspector()
    }
    func changeSelectedAnnotation(delete: Bool) throws {
        guard let annotation = selectedAnnotation, let page = pdfView.currentPage else { return }
        let text = contentText.string
        try doc.change(delete ? "Delete annotation" : "Update annotation") { _ in
            if delete { page.removeAnnotation(annotation) } else { annotation.contents = text }
        }
        if delete { selectedAnnotation = nil; reloadInspector() }
    }
    func updateSelectedField(_ command: String) throws {
        guard let field = selectedAnnotation, !field.isReadOnly else { return }
        if field.widgetFieldType == .button && field.widgetControlType != .checkBoxControl {
            Dialogs.info("Unsupported control", "Only checkbox buttons are editable in this inspector. Radio groups and scripted buttons need separate handling."); return
        }
        let value = command == "applyChoice" ? fieldChoices.titleOfSelectedItem ?? "" : fieldValue.stringValue
        try doc.change("Fill PDF form") { _ in
            if command == "toggleField" { field.buttonWidgetState = field.buttonWidgetState == .onState ? .offState : .onState }
            else { field.widgetStringValue = value }
        }
    }
    func selectedPageOperation(_ action: String) throws {
        var indices = Array(pageList.selectedRowIndexes)
        if indices.isEmpty { indices = [currentIndex] }
        guard indices.allSatisfy({ $0 >= 0 && $0 < doc.pdf.pageCount }) else { throw PDFError.invalidPages }
        if action == "rotateSelected" { try doc.change("Rotate pages") { pdf in for index in indices { pdf.page(at: index)?.rotation += 90 } } }
        else if action == "deleteSelected" {
            guard indices.count < doc.pdf.pageCount else { throw PDFError.invalidPages }
            try doc.change("Delete pages") { pdf in for index in indices.sorted(by: >) { pdf.removePage(at: index) } }
        } else if let url = Dialogs.save(name: "Extracted.pdf", type: .pdf) {
            try PDFOperations.data(PDFOperations.extract(doc.pdf, indices: indices)).write(to: url, options: .atomic)
        }
    }
    func selectContent(on page: PDFPage, at point: CGPoint) {
        if workspace != .edit { setWorkspace(.edit) }
        pdfView.go(to: page); reloadInspector()
        selectedContent = contentObjects.filter { $0.bounds.insetBy(dx: -3, dy: -3).contains(point) }.min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
        updatingInspector = true; rebuildInspector(); updatingInspector = false
        if let selected = selectedContent, let row = contentObjects.firstIndex(where: { $0.id == selected.id }) { contentList.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        pdfView.redactionOverlay.needsDisplay = true
    }
}
