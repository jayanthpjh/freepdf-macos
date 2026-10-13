import AppKit
import PDFKit
import FreePDFCore

enum WorkspaceMode: String, CaseIterable {
    case read = "Read", edit = "Edit PDF", annotate = "Annotate", pages = "Pages", forms = "Fill & Sign", ocr = "Scan & OCR", export = "Export"
}

final class FlippedStackView: NSStackView { override var isFlipped: Bool { true } }

final class WorkspaceButton: NSButton { var command = "" }

extension EditorWindowController {
    func buildLayout() {
        guard let root = window?.contentView else { return }
        let toolbar = NSStackView(); toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        toolbar.addArrangedSubview(button("Open PDF", action: #selector(openDocument)))
        toolbar.addArrangedSubview(button("Save", action: #selector(saveDocument)))
        toolbar.addArrangedSubview(button("Save As", action: #selector(saveCopy)))
        let spring = NSView(); spring.setContentHuggingPriority(.defaultLow, for: .horizontal)
        toolbar.addArrangedSubview(spring)
        search.placeholderString = "Find text in document"; search.delegate = self
        search.target = self; search.action = #selector(findText)
        search.widthAnchor.constraint(equalToConstant: 220).isActive = true
        toolbar.addArrangedSubview(search)
        toolbar.addArrangedSubview(button("−", action: #selector(zoomOut)))
        toolbar.addArrangedSubview(button("+", action: #selector(zoomIn)))
        toolbar.addArrangedSubview(button("Fit page", action: #selector(fit)))
        toolbar.addArrangedSubview(button("Inspector", action: #selector(toggleInspector)))

        modeControl.segmentCount = WorkspaceMode.allCases.count
        for (index, mode) in WorkspaceMode.allCases.enumerated() { modeControl.setLabel(mode.rawValue, forSegment: index) }
        modeControl.selectedSegment = 0; modeControl.target = self; modeControl.action = #selector(workspaceChanged)
        modeControl.segmentStyle = .texturedRounded
        let modeBar = NSStackView(views: [modeControl]); modeBar.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 10, right: 16)
        modeBar.distribution = .fill

        sidebarSwitch.segmentCount = 2; sidebarSwitch.setLabel("All tools", forSegment: 0); sidebarSwitch.setLabel("Page thumbnails", forSegment: 1)
        sidebarSwitch.selectedSegment = 0; sidebarSwitch.target = self; sidebarSwitch.action = #selector(sidebarChanged)
        let brand = label("FreePDF", size: 17, weight: .semibold)
        let sidebarHeader = NSStackView(views: [brand, sidebarSwitch]); sidebarHeader.orientation = .vertical; sidebarHeader.alignment = .leading; sidebarHeader.spacing = 14
        sidebarHeader.edgeInsets = NSEdgeInsets(top: 18, left: 14, bottom: 14, right: 14)
        let toolColumn = FlippedStackView(); toolColumn.orientation = .vertical; toolColumn.alignment = .leading; toolColumn.spacing = 4
        toolColumn.edgeInsets = NSEdgeInsets(top: 2, left: 10, bottom: 20, right: 10)
        for (title, command, symbol) in [
            ("Read & navigate", "mode:Read", "doc.text"),
            ("Edit text & images", "mode:Edit PDF", "square.and.pencil"),
            ("Comment & annotate", "mode:Annotate", "highlighter"),
            ("Organize pages", "mode:Pages", "rectangle.grid.2x2"),
            ("Fill & sign", "mode:Fill & Sign", "signature"),
            ("Scan & recognize text", "mode:Scan & OCR", "text.viewfinder"),
            ("Export & protect", "mode:Export", "square.and.arrow.up")
        ] {
            let control = actionButton(title, command: command, symbol: symbol)
            control.isBordered = false; control.bezelStyle = .recessed;
            if command == "mode:Read" { control.state = .on; control.contentTintColor = .systemTeal }; control.font = .systemFont(ofSize: 13)
            toolColumn.addArrangedSubview(control); modeButtons.append(control)
        }
        toolColumn.addArrangedSubview(NSBox.separator())
        toolColumn.addArrangedSubview(label("Document actions", size: 11, weight: .semibold, secondary: true))
        for (title, command, symbol) in [("Combine PDFs", "merge", "doc.on.doc"), ("Split into files", "split", "rectangle.split.2x1"),
                                       ("Compress PDF", "compress", "arrow.down.right.and.arrow.up.left"), ("Add watermark", "watermark", "seal"),
                                       ("Compare text", "compare", "doc.text.magnifyingglass"), ("Batch OCR", "batchOCR", "square.stack.3d.up"),
                                       ("Document properties", "properties", "info.circle")] {
            let control = actionButton(title, command: command, symbol: symbol); control.isBordered = false
            toolColumn.addArrangedSubview(control)
        }
        toolColumn.addArrangedSubview(label("Your documents stay on this Mac.", size: 11, secondary: true))
        for view in toolColumn.arrangedSubviews { view.widthAnchor.constraint(equalToConstant: 190).isActive = true }
        toolsScroll.documentView = toolColumn; toolsScroll.hasVerticalScroller = true; toolsScroll.autohidesScrollers = true
        toolColumn.translatesAutoresizingMaskIntoConstraints = false
        toolColumn.widthAnchor.constraint(equalTo: toolsScroll.contentView.widthAnchor).isActive = true
        let pageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Page")); pageColumn.title = "Pages"; pageColumn.width = 198
        pageList.addTableColumn(pageColumn); pageList.headerView = nil; pageList.rowHeight = 166; pageList.intercellSpacing = NSSize(width: 0, height: 8)
        pageList.delegate = self; pageList.dataSource = self; pageList.allowsMultipleSelection = true
        pageList.registerForDraggedTypes([Self.pagePasteboardType]); pageList.setDraggingSourceOperationMask(.move, forLocal: true)
        pageScroll.documentView = pageList; pageScroll.hasVerticalScroller = true; pageScroll.autohidesScrollers = true
        sidebarBody.addArrangedSubview(toolsScroll); sidebarBody.addArrangedSubview(pageScroll)
        sidebarBody.orientation = .vertical; sidebarBody.spacing = 0
        pageScroll.isHidden = true
        let sidebar = NSStackView(views: [sidebarHeader, sidebarBody]); sidebar.orientation = .vertical; sidebar.spacing = 0; sidebar.alignment = .leading
        sidebar.widthAnchor.constraint(equalToConstant: 220).isActive = true
        for view in sidebar.arrangedSubviews { view.widthAnchor.constraint(equalTo: sidebar.widthAnchor).isActive = true }
        sidebarBody.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        for view in sidebarBody.arrangedSubviews { view.widthAnchor.constraint(equalTo: sidebarBody.widthAnchor).isActive = true }

        pdfView.autoScales = true; pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = .underPageBackgroundColor
        inspectorScroll.hasVerticalScroller = true; inspectorScroll.autohidesScrollers = true
        inspectorColumn.orientation = .vertical; inspectorColumn.alignment = .leading; inspectorColumn.spacing = 12
        inspectorColumn.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 20, right: 16)
        inspectorColumn.translatesAutoresizingMaskIntoConstraints = false
        inspectorScroll.documentView = inspectorColumn
        inspectorColumn.widthAnchor.constraint(equalTo: inspectorScroll.contentView.widthAnchor).isActive = true
        inspectorScroll.widthAnchor.constraint(equalToConstant: 258).isActive = true
        workspaceSplit.isVertical = true; workspaceSplit.dividerStyle = .thin
        workspaceSplit.addArrangedSubview(sidebar); workspaceSplit.addArrangedSubview(pdfView); workspaceSplit.addArrangedSubview(inspectorScroll)

        let footer = NSStackView(); footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        footer.addArrangedSubview(button("‹", action: #selector(previousPage)))
        pageNumber.frame.size.width = 42; pageNumber.alignment = .center; pageNumber.target = self; pageNumber.action = #selector(jumpToPage)
        pageNumber.widthAnchor.constraint(equalToConstant: 42).isActive = true; pageNumber.setAccessibilityLabel("Page number")
        footer.addArrangedSubview(pageNumber)
        footer.addArrangedSubview(button("›", action: #selector(nextPage)))
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        footer.addArrangedSubview(status)
        footer.addArrangedSubview(button("Cancel task", action: #selector(cancelJob)))
        let column = NSStackView(views: [toolbar, NSBox.separator(), modeBar, workspaceSplit, footer]); column.orientation = .vertical; column.spacing = 0; column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(column)
        NSLayoutConstraint.activate([column.leadingAnchor.constraint(equalTo: root.leadingAnchor), column.trailingAnchor.constraint(equalTo: root.trailingAnchor), column.topAnchor.constraint(equalTo: root.topAnchor), column.bottomAnchor.constraint(equalTo: root.bottomAnchor)])
        for view in column.arrangedSubviews { view.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true }
        workspaceSplit.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
        color.color = .systemTeal; fontSize.addItems(withTitles: ["10", "12", "16", "20", "24", "32", "48"]); fontSize.selectItem(withTitle: "16")
        toolPicker.addItems(withTitles: CanvasTool.allCases.map(\.rawValue)); toolPicker.target = self; toolPicker.action = #selector(toolChanged)
        contentFont.addItems(withTitles: ContentEditing.Font.allCases.map(\.rawValue)); contentFont.selectItem(withTitle: "Helvetica")
    }
    func label(_ text: String, size: CGFloat = 12, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text); field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = secondary ? .secondaryLabelColor : .labelColor; return field
    }
    func actionButton(_ title: String, command: String, symbol: String? = nil) -> WorkspaceButton {
        let control = WorkspaceButton(title: title, target: self, action: #selector(workspaceAction(_:)))
        control.command = command; control.bezelStyle = .rounded; control.alignment = .left
        control.font = .systemFont(ofSize: 12); control.setAccessibilityLabel(title)
        if let symbol { control.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); control.imagePosition = .imageLeading }
        control.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return control
    }
}

extension NSBox {
    static func separator() -> NSBox { let box = NSBox(); box.boxType = .separator; return box }
}
