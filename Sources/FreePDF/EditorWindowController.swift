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
    var workspace: WorkspaceMode = .read
    let modeControl = NSSegmentedControl()
    var modeButtons: [WorkspaceButton] = []
    let sidebarSwitch = NSSegmentedControl()
    let sidebarBody = NSStackView()
    let toolsScroll = NSScrollView()
    let pageScroll = NSScrollView()
    let pageList = NSTableView()
    let inspectorScroll = NSScrollView()
    let inspectorColumn = FlippedStackView()
    let workspaceSplit = NSSplitView()
    let pageNumber = NSTextField(string: "1")
    let contentList = NSTableView()
    let contentText = NSTextView()
    let contentFont = NSPopUpButton()
    let objectSize = NSTextField(string: "16")
    var rectFields: [NSTextField] = []
    var contentObjects: [PDFContentObject] = []
    var selectedContent: PDFContentObject?
    var pageAnnotations: [PDFAnnotation] = []
    var selectedAnnotation: PDFAnnotation?
    var inspectorMessage = ""
    var updatingInspector = false
    var inspectedPage: Int?
    let fieldValue = NSTextField(string: "")
    let fieldChoices = NSPopUpButton()
    let ocrLanguage = NSPopUpButton()
    static let pagePasteboardType = NSPasteboard.PasteboardType("io.github.freepdf.page-index")
    var progressTimer: Timer?
    var job: Progress?
    var pendingRegions: [Int: [CGRect]] = [:]
    var doc: FreePDFDocument { document as! FreePDFDocument }
    var currentIndex: Int { pdfView.currentPage.map { doc.pdf.index(for: $0) } ?? 0 }
    var selectedColor: NSColor { color.color }
    var textSize: CGFloat { CGFloat(Double(fontSize.titleOfSelectedItem ?? "16") ?? 16) }
    private var observers: [NSObjectProtocol] = []

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.minSize = NSSize(width: 1040, height: 620)
        window.title = "FreePDF"; window.center()
        window.tabbingMode = .preferred
        buildLayout()
        pdfView.onRegion = { [weak self] page, rect, points in self?.addRegion(page, rect, points) }
        pdfView.redactionRegions = { [weak self] in self?.pendingRegions ?? [:] }
        pdfView.onWidget = { [weak self] in self?.setWorkspace(.forms) }
        pdfView.onContentHit = { [weak self] page, point in self?.selectContent(on: page, at: point) }
        pdfView.selectedRegion = { [weak self] in
            guard let self, let page = self.pdfView.currentPage else { return nil }
            if let object = self.selectedContent { return (page, object.bounds) }
            if let annotation = self.selectedAnnotation { return (page, annotation.bounds) }
            return nil
        }
        for name in [Notification.Name.PDFViewPageChanged, .PDFViewScaleChanged] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: pdfView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateStatus(); self?.reloadInspector(); self?.pdfView.redactionOverlay.needsDisplay = true }
            })
        }
    }
    required init?(coder: NSCoder) { fatalError("Use init()") }
    deinit { progressTimer?.invalidate(); job?.cancel(); observers.forEach(NotificationCenter.default.removeObserver) }

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
        pageList.reloadData()
        reloadInspector()
        updateStatus()
    }
    func updateStatus() {
        guard document is FreePDFDocument else { return }
        pageNumber.stringValue = "\(currentIndex + 1)"
        if pageList.selectedRowIndexes.count <= 1, pageList.selectedRow != currentIndex {
            let previous = updatingInspector; updatingInspector = true
            pageList.selectRowIndexes(IndexSet(integer: currentIndex), byExtendingSelection: false)
            updatingInspector = previous
        }
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
    @objc func fit() { pdfView.autoScales = false; pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit }
    @objc func nextPage() { pdfView.goToNextPage(nil) }
    @objc func previousPage() { pdfView.goToPreviousPage(nil) }
    @objc func toolChanged() {
        pdfView.tool = CanvasTool(rawValue: toolPicker.titleOfSelectedItem ?? "") ?? .select
        reloadInspector()
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
