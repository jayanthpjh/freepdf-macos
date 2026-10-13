import AppKit
import PDFKit

enum CanvasTool: String, CaseIterable {
    case select = "Select", text = "Text box", note = "Note", rectangle = "Rectangle", oval = "Oval", ink = "Draw", redact = "Redact area", replace = "Replace area"
}

final class CanvasView: PDFView {
    var tool: CanvasTool = .select
    var onRegion: ((PDFPage, CGRect, [CGPoint]) -> Void)?
    var onWidget: (() -> Void)?
    var redactionRegions: (() -> [Int: [CGRect]])?
    lazy var redactionOverlay: RedactionOverlay = {
        let view = RedactionOverlay()
        view.canvas = self
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .above, relativeTo: nil)
        return view
    }()
    override func layout() {
        super.layout()
        redactionOverlay.frame = bounds
        redactionOverlay.needsDisplay = true
    }

    private var start: CGPoint?
    private var drawingPage: PDFPage?
    private var points: [CGPoint] = []
    private var preview: PDFAnnotation?
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let page = page(for: point, nearest: false) else { super.mouseDown(with: event); return }
        if tool == .select {
            let location = convert(point, to: page)
            if page.annotation(at: location)?.type == "Widget" {
                onWidget?()
                return // Form edits go through our undoable form inspector.
            }
            super.mouseDown(with: event); return
        }
        start = convert(point, to: page)
        drawingPage = page
        points = [start!]
    }
    override func mouseDragged(with event: NSEvent) {
        guard tool != .select, let page = drawingPage, let start else { super.mouseDragged(with: event); return }
        let point = convert(convert(event.locationInWindow, from: nil), to: page)
        points.append(point)
        if let preview { page.removeAnnotation(preview) }
        let rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y), width: abs(start.x - point.x), height: abs(start.y - point.y))
        let annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
        annotation.color = .systemTeal
        let border = PDFBorder(); border.lineWidth = 1; border.dashPattern = [4, 3]
        annotation.border = border
        annotation.shouldPrint = false
        page.addAnnotation(annotation); preview = annotation
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard tool != .select, let page = drawingPage, let start else { super.mouseUp(with: event); return }
        if let preview { page.removeAnnotation(preview) }; preview = nil
        let end = convert(convert(event.locationInWindow, from: nil), to: page)
        let box = page.bounds(for: .cropBox)
        let geometry = tool == .ink ? points + [end] : [start, end]
        let minX = geometry.map(\.x).min()!, maxX = geometry.map(\.x).max()!
        let minY = geometry.map(\.y).min()!, maxY = geometry.map(\.y).max()!
        let rect = CGRect(x: minX, y: minY, width: max(24, maxX - minX), height: max(24, maxY - minY)).intersection(box)
        points.append(end)
        self.start = nil; drawingPage = nil
        if !rect.isNull { onRegion?(page, rect, points) }
        needsDisplay = true
    }
}

final class RedactionOverlay: NSView {
    weak var canvas: CanvasView?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let canvas, let document = canvas.document else { return }
        for (index, regions) in canvas.redactionRegions?() ?? [:] {
            guard let page = document.page(at: index) else { continue }
            for region in regions {
                let rect = canvas.convert(region, from: page)
                guard dirtyRect.intersects(rect) else { continue }
                NSColor.systemRed.withAlphaComponent(0.18).setFill()
                NSBezierPath(rect: rect).fill()
                NSColor.systemRed.setStroke()
                let path = NSBezierPath(rect: rect); path.lineWidth = 2; path.stroke()
            }
        }
    }
}
