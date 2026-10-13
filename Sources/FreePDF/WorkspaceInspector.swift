import AppKit
import PDFKit
import FreePDFCore

extension EditorWindowController {
    func reloadInspector() {
        guard document is FreePDFDocument, !updatingInspector else { return }
        updatingInspector = true; defer { updatingInspector = false }
        if inspectedPage != currentIndex { selectedContent = nil; selectedAnnotation = nil }
        inspectedPage = currentIndex
        inspectorMessage = ""
        if workspace == .edit {
            do {
                contentObjects = try ContentEditing.objects(in: PDFOperations.data(doc.pdf), page: currentIndex, password: doc.unlockPassword)
                if let selected = selectedContent { selectedContent = contentObjects.first { $0.id == selected.id } }
            } catch { contentObjects = []; selectedContent = nil; inspectorMessage = error.localizedDescription }
        }
        if workspace == .annotate || workspace == .forms {
            let previous = selectedAnnotation.flatMap { selected in pageAnnotations.firstIndex { $0 === selected } }
            pageAnnotations = pdfView.currentPage?.annotations.filter { workspace == .forms ? $0.type == "Widget" : $0.type != "Widget" } ?? []
            selectedAnnotation = previous.flatMap { pageAnnotations.indices.contains($0) ? pageAnnotations[$0] : nil }
        }
        rebuildInspector()
        pdfView.redactionOverlay.needsDisplay = true
    }
    func addInspector(_ view: NSView) {
        inspectorColumn.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: inspectorColumn.widthAnchor, constant: -32).isActive = true
    }
    func rebuildInspector() {
        for view in inspectorColumn.arrangedSubviews { inspectorColumn.removeArrangedSubview(view); view.removeFromSuperview() }
        addInspector(label(workspace.rawValue, size: 17, weight: .semibold))
        let descriptions: [WorkspaceMode: String] = [
            .read: "Read, search, and navigate your document.", .edit: "Select text or an image on the page, or choose an item below.",
            .annotate: "Mark up your document and review comments.", .pages: "Select page thumbnails. Drag them to reorder.",
            .forms: "Fill existing fields or add a visible signature.", .ocr: "Make scanned pages searchable on this Mac.", .export: "Create an exported copy of your document."
        ]
        addInspector(label(descriptions[workspace] ?? "", secondary: true))
        if workspace == .edit { addInspector(label("Editing converts this page’s vector colors to RGB. Keep the original for print workflows.", size: 11, secondary: true)) }
        if !inspectorMessage.isEmpty { addInspector(label(inspectorMessage, secondary: true)) }
        switch workspace {
        case .read:
            addInspector(label("Navigation", size: 12, weight: .semibold))
            for (title, action) in [("Show page thumbnails", "showPages"), ("Document bookmarks", "outline"), ("Add bookmark", "bookmark"), ("Single-page view", "single"), ("Continuous view", "continuous"), ("Two-page view", "twoUp")] { addInspector(actionButton(title, command: action)) }
            addInspector(label("Quick actions", size: 12, weight: .semibold))
            addInspector(actionButton("Highlight selected text", command: "highlight"))
            addInspector(actionButton("Add a note", command: "tool:Note"))
            addInspector(actionButton("Document properties", command: "properties"))
        case .edit:
            addInspector(label("Content on page \(currentIndex + 1)", size: 12, weight: .semibold))
            addInspector(objectTable())
            if contentObjects.isEmpty { addInspector(label("No editable text or images on this page. Run OCR for scans. Content inside grouped PDF objects is not yet supported.", secondary: true)) }
            if let object = selectedContent {
                addInspector(label(object.kind == .text ? "Edit selected text" : "Edit selected image", size: 12, weight: .semibold))
                if object.kind == .text {
                    configureContentText(object.text)
                    let scroll = NSScrollView(); scroll.documentView = contentText; scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
                    contentText.isVerticallyResizable = true; contentText.isHorizontallyResizable = false
                    contentText.textContainer?.widthTracksTextView = false
                    contentText.setAccessibilityLabel("Replacement text")
                    scroll.heightAnchor.constraint(equalToConstant: 76).isActive = true; addInspector(scroll)
                    addInspector(label("Replacement font", size: 11, secondary: true)); addInspector(contentFont)
                    objectSize.stringValue = String(format: "%.1f", object.fontSize)
                    addInspector(fieldRow("Size", field: objectSize))
                    addInspector(actionButton("Apply text change", command: "applyText"))
                    addInspector(label("Keeps the original position. Text does not reflow; longer lines can overlap nearby content. A chosen standard font replaces the embedded font.", size: 11, secondary: true))
                } else { addInspector(actionButton("Replace image…", command: "replaceImage")) }
                addInspector(label("Position & size", size: 12, weight: .semibold))
                rectFields = [object.bounds.minX, object.bounds.minY, object.bounds.width, object.bounds.height].map { value in
                    let field = NSTextField(string: String(format: "%.1f", value)); field.font = .systemFont(ofSize: 12); return field
                }
                for (index, name) in ["X", "Y", "Width", "Height"].enumerated() { rectFields[index].setAccessibilityLabel(name); addInspector(fieldRow(name, field: rectFields[index])) }
                addInspector(actionButton("Apply position & size", command: "applyBounds"))
                addInspector(actionButton("Delete selected content", command: "deleteContent"))
                addInspector(label("Coordinates use PDF points from the page's lower-left corner.", size: 11, secondary: true))
            }
        case .annotate:
            addInspector(label("Annotation tools", size: 12, weight: .semibold))
            addInspector(toolPicker)
            addInspector(fieldRow("Color", field: color))
            addInspector(fieldRow("Text size", field: fontSize))
            for (title, action) in [("Highlight selection", "highlight"), ("Underline selection", "underline"), ("Strike through", "strike")] { addInspector(actionButton(title, command: action)) }
            addInspector(label("Comments on this page", size: 12, weight: .semibold)); addInspector(objectTable())
            if let annotation = selectedAnnotation {
                configureContentText(annotation.contents ?? "")
                let scroll = NSScrollView(); scroll.documentView = contentText; scroll.borderType = .bezelBorder; scroll.hasVerticalScroller = true
                scroll.heightAnchor.constraint(equalToConstant: 64).isActive = true; addInspector(scroll)
                addInspector(actionButton("Update comment", command: "updateComment")); addInspector(actionButton("Delete annotation", command: "deleteAnnotation"))
            } else { addInspector(label("Choose a tool and drag on the page, or select a comment above.", size: 11, secondary: true)) }
            addInspector(actionButton("Mark redaction area", command: "tool:Redact area")); addInspector(actionButton("Create redacted copy", command: "applyRedactions"))
        case .pages:
            for (title, action) in [("Rotate selected pages", "rotateSelected"), ("Delete selected pages", "deleteSelected"), ("Extract selected pages", "extractSelected"), ("Insert a blank page", "blank"), ("Insert another PDF", "merge"), ("Insert images", "images"), ("Split into individual files", "split"), ("Crop current page", "crop"), ("Add page numbers", "numbers")] { addInspector(actionButton(title, command: action)) }
        case .forms:
            addInspector(label("Fields on this page", size: 12, weight: .semibold)); addInspector(objectTable())
            if let field = selectedAnnotation {
                addInspector(label(field.fieldName ?? "Form field", size: 12, weight: .semibold))
                if field.isReadOnly { addInspector(label("This field is read-only.", secondary: true)) }
                else if field.widgetFieldType == .button { addInspector(actionButton(field.buttonWidgetState == .onState ? "Uncheck field" : "Check field", command: "toggleField")) }
                else if field.widgetFieldType == .choice, let choices = field.choices {
                    fieldChoices.removeAllItems(); fieldChoices.addItems(withTitles: choices); fieldChoices.selectItem(withTitle: field.widgetStringValue ?? "")
                    addInspector(fieldChoices); addInspector(actionButton("Apply field value", command: "applyChoice"))
                } else { fieldValue.stringValue = field.widgetStringValue ?? ""; fieldValue.setAccessibilityLabel("Form field value"); addInspector(fieldValue); addInspector(actionButton("Apply field value", command: "applyField")) }
            } else { addInspector(label("Choose a field above. XFA forms and scripted actions are unsupported.", size: 11, secondary: true)) }
            addInspector(actionButton("Add text form field", command: "createForm")); addInspector(actionButton("Place signature image", command: "signature"))
            addInspector(label("Signature images are visible marks, not certificate signatures.", size: 11, secondary: true))
        case .ocr:
            addInspector(label("Recognition language", size: 12, weight: .semibold))
            if ocrLanguage.numberOfItems == 0 {
                for code in (try? LocalOCR.languages()) ?? ["en-US"] {
                    ocrLanguage.addItem(withTitle: Locale.current.localizedString(forIdentifier: code) ?? code); ocrLanguage.lastItem?.representedObject = code
                    if code == "en-US" { ocrLanguage.select(ocrLanguage.lastItem) }
                }
            }
            addInspector(ocrLanguage); addInspector(actionButton("Recognize this document", command: "recognizeNow"))
            addInspector(label("Creates a new searchable copy. Existing text pages are preserved. Scanned pages gain a text layer; recognition can need corrections.", secondary: true))
            addInspector(actionButton("Batch OCR (English)", command: "batchOCR"))
        case .export:
            for (title, action) in [("PDF pages…", "extract"), ("Page as PNG…", "png"), ("Plain text…", "textExport"), ("Rich text…", "rtf"), ("Flattened PDF…", "flatten"), ("Compressed PDF…", "compress"), ("Password-protected PDF…", "encrypt")] { addInspector(actionButton(title, command: action)) }
            addInspector(label("Word, Excel, and PowerPoint conversion are not implemented. Flattening removes editable structure.", size: 11, secondary: true))
        }
    }
    func configureContentText(_ value: String) {
        contentText.frame = NSRect(x: 0, y: 0, width: 218, height: 76)
        contentText.autoresizingMask = [.width]
        contentText.minSize = NSSize(width: 0, height: 76)
        contentText.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        contentText.isVerticallyResizable = true; contentText.isHorizontallyResizable = false
        contentText.textContainer?.containerSize = NSSize(width: 210, height: CGFloat.greatestFiniteMagnitude)
        contentText.textContainer?.widthTracksTextView = false
        contentText.textContainerInset = NSSize(width: 4, height: 4)
        contentText.font = .systemFont(ofSize: 12); contentText.textColor = .textColor
        contentText.backgroundColor = .textBackgroundColor; contentText.isRichText = false
        contentText.string = value
    }
    func fieldRow(_ title: String, field: NSView) -> NSStackView {
        let caption = label(title, size: 11, secondary: true); caption.widthAnchor.constraint(equalToConstant: 66).isActive = true
        let row = NSStackView(views: [caption, field]); row.spacing = 8
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }
    func objectTable() -> NSScrollView {
        if contentList.tableColumns.isEmpty {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Content")); column.width = 216; contentList.addTableColumn(column)
            contentList.headerView = nil; contentList.rowHeight = 40; contentList.delegate = self; contentList.dataSource = self
        }
        contentList.reloadData()
        let scroll = NSScrollView(); scroll.documentView = contentList; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true
        return scroll
    }
}
