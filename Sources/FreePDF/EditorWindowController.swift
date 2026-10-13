import AppKit
import PDFKit
import FreePDFCore

@MainActor
final class EditorWindowController: NSWindowController, NSSearchFieldDelegate {
    let pdfView = CanvasView()
    let thumbnails = PDFThumbnailView()
    let status = NSTextField(labelWithString: "")
    let search = NSSearchField()
    let toolPicker = NSPopUpButton()
    let color = NSColorWell()
    let fontSize = NSPopUpButton()
    var progressTimer: Timer?
    var job: Progress?
    var pendingRegions: [Int: [CGRect]] = [:]
    var doc: FreePDFDocument { document as! FreePDFDocument }
    var currentIndex: Int { pdfView.currentPage.map { doc.pdf.index(for: $0) } ?? 0 }
    var selectedColor: NSColor { color.color }
    var textSize: CGFloat { CGFloat(Double(fontSize.titleOfSelectedItem ?? "16") ?? 16) }
    private var observers: [NSObjectProtocol] = []

    init(document: FreePDFDocument) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        self.document = document
        window.minSize = NSSize(width: 850, height: 560)
        window.title = "FreePDF"; window.center()
        window.tabbingMode = .preferred
        buildLayout()
        pdfView.onRegion = { [weak self] page, rect, points in self?.addRegion(page, rect, points) }
        pdfView.redactionRegions = { [weak self] in self?.pendingRegions ?? [:] }
        pdfView.onWidget = { [weak self] in self?.perform("forms") }
        for name in [Notification.Name.PDFViewPageChanged, .PDFViewScaleChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: pdfView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateStatus(); self?.pdfView.redactionOverlay.needsDisplay = true }
            })
        }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("Use init(document:)") }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func buildLayout() {
        guard let root = window?.contentView else { return }
        let bar = NSStackView(); bar.spacing = 8; bar.orientation = .horizontal
        bar.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        bar.addArrangedSubview(button("Open", action: #selector(openDocument)))
        bar.addArrangedSubview(button("Save", action: #selector(saveDocument)))
        let modes = NSStackView(); modes.spacing = 4
        for (title, command) in [("Annotate", "annotateMenu"), ("Pages", "pagesMenu"), ("Tools", "toolsMenu"), ("Export", "exportMenu")] {
            let popup = NSPopUpButton(); popup.pullsDown = true
            popup.addItem(withTitle: title)
            for (label, action) in commands(for: command) {
                popup.addItem(withTitle: label)
                let item = popup.lastItem!; item.target = self; item.action = #selector(menuCommand(_:)); item.representedObject = action
            }
            modes.addArrangedSubview(popup)
        }
        bar.addArrangedSubview(modes)
        search.placeholderString = "Find in document"; search.delegate = self
        search.target = self; search.action = #selector(findText)
        search.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        bar.addArrangedSubview(search)
        bar.addArrangedSubview(button("−", action: #selector(zoomOut)))
        bar.addArrangedSubview(button("+", action: #selector(zoomIn)))
        bar.addArrangedSubview(button("Fit", action: #selector(fit)))

        let annotationBar = NSStackView(); annotationBar.spacing = 10
        annotationBar.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        toolPicker.addItems(withTitles: CanvasTool.allCases.map(\.rawValue))
        toolPicker.target = self; toolPicker.action = #selector(toolChanged)
        annotationBar.addArrangedSubview(NSTextField(labelWithString: "Tool")); annotationBar.addArrangedSubview(toolPicker)
        color.color = .systemTeal; color.widthAnchor.constraint(equalToConstant: 44).isActive = true
        color.setAccessibilityLabel("Annotation color")
        annotationBar.addArrangedSubview(color)
        annotationBar.addArrangedSubview(NSTextField(labelWithString: "Text size"))
        fontSize.addItems(withTitles: ["10", "12", "16", "20", "24", "32", "48"]); fontSize.selectItem(withTitle: "16")
        annotationBar.addArrangedSubview(fontSize)
        annotationBar.addArrangedSubview(button("Highlight", action: #selector(highlight)))
        annotationBar.addArrangedSubview(button("Apply redactions", action: #selector(applyRedactions)))
        annotationBar.addArrangedSubview(button("Cancel task", action: #selector(cancelJob)))

        pdfView.autoScales = true; pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = .windowBackgroundColor
        thumbnails.pdfView = pdfView; thumbnails.thumbnailSize = NSSize(width: 100, height: 130)
        thumbnails.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let split = NSSplitView(); split.isVertical = true; split.dividerStyle = .thin
        split.addArrangedSubview(thumbnails); split.addArrangedSubview(pdfView)
        let footer = NSStackView(); footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        footer.addArrangedSubview(button("‹", action: #selector(previousPage)))
        footer.addArrangedSubview(button("›", action: #selector(nextPage)))
        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        footer.addArrangedSubview(status)
        let column = NSStackView(views: [bar, annotationBar, split, footer]); column.orientation = .vertical; column.spacing = 0; column.alignment = .leading
        column.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(column)
        NSLayoutConstraint.activate([column.leadingAnchor.constraint(equalTo: root.leadingAnchor), column.trailingAnchor.constraint(equalTo: root.trailingAnchor), column.topAnchor.constraint(equalTo: root.topAnchor), column.bottomAnchor.constraint(equalTo: root.bottomAnchor)])
        for view in [bar, annotationBar, split, footer] { view.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true }
        split.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
    }
    func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded; button.setAccessibilityLabel(title)
        return button
    }
    func refresh(index requestedIndex: Int? = nil) {
        pendingRegions = [:]
        let index = min(requestedIndex ?? currentIndex, max(0, doc.pdf.pageCount - 1))
        pdfView.document = doc.pdf
        if let page = doc.pdf.page(at: index) { pdfView.go(to: page) }
        thumbnails.pdfView = pdfView
        pdfView.redactionOverlay.needsDisplay = true
        pdfView.needsDisplay = true
        updateStatus()
    }
    func updateStatus() {
        let progress = job.map { " · Processing \($0.completedUnitCount)/\($0.totalUnitCount)" } ?? ""
        status.stringValue = "Page \(currentIndex + 1) of \(doc.pdf.pageCount) · \(Int(pdfView.scaleFactor * 100))% · \(pdfView.tool.rawValue)\(progress)"
    }
    func safely(_ work: () throws -> Void) {
        guard job == nil else { Dialogs.info("Task in progress", "Cancel or wait for the current operation before editing."); return }
        do { try work() } catch { Dialogs.error(error) }
    }
    @objc func openDocument() { NSDocumentController.shared.openDocument(nil) }
    @objc func saveDocument() { doc.save(nil) }
    @objc func zoomIn() { pdfView.zoomIn(nil) }
    @objc func zoomOut() { pdfView.zoomOut(nil) }
    @objc func fit() { pdfView.autoScales = true }
    @objc func nextPage() { pdfView.goToNextPage(nil) }
    @objc func previousPage() { pdfView.goToPreviousPage(nil) }
    @objc func toolChanged() {
        pdfView.tool = CanvasTool(rawValue: toolPicker.titleOfSelectedItem ?? "") ?? .select
        updateStatus()
    }
    @objc func menuCommand(_ sender: NSMenuItem) { if let command = sender.representedObject as? String { perform(command) } }
    @objc func cancelJob() { job?.cancel() }
    @objc func highlight() { perform("highlight") }
    @objc func applyRedactions() { perform("applyRedactions") }
    @objc func findText() {
        guard !search.stringValue.isEmpty else { pdfView.clearSelection(); return }
        if let selection = doc.pdf.findString(search.stringValue, fromSelection: pdfView.currentSelection, withOptions: .caseInsensitive) ?? doc.pdf.findString(search.stringValue, withOptions: .caseInsensitive).first {
            pdfView.setCurrentSelection(selection, animate: true); pdfView.go(to: selection)
        } else { status.stringValue = "No matches for “\(search.stringValue)”" }
    }
    func controlTextDidChange(_ notification: Notification) {
        // Search is initiated on Return to keep large-document typing responsive.
    }
}
