import AppKit
import CoreText
import PDFKit

@MainActor
func makeSampleDocument() throws -> PDFDocument {
    let buffer = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: buffer), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw CocoaError(.fileReadCorruptFile) }
    func text(_ string: String, x: CGFloat = 54, y: CGFloat, size: CGFloat = 12, bold: Bool = false, color: NSColor = .black) {
        let font = CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor]))
        context.textMatrix = .identity; context.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, context)
    }
    func header(_ title: String, page: Int) {
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor); context.fill(box)
        text("SAMPLE DOCUMENT · FICTIONAL CONTENT", y: 738, size: 9, color: .gray)
        text(title, y: 683, size: 30, bold: true)
        context.setStrokeColor(NSColor.systemTeal.cgColor); context.setLineWidth(2)
        context.move(to: CGPoint(x: 54, y: 658)); context.addLine(to: CGPoint(x: 558, y: 658)); context.strokePath()
        text("FreePDF sample • Page \(page) of 3", y: 34, size: 9, color: .gray)
    }
    header("Project brief", page: 1)
    text("Autumn print collection", y: 614, size: 17, bold: true)
    for (offset, line) in ["A small collection of printed materials for the studio.", "This fictional brief is provided so you can try reading, editing,", "annotating, and organizing a real multi-page PDF."].enumerated() { text(line, y: CGFloat(578 - offset * 20)) }
    text("Project overview", y: 486, size: 15, bold: true)
    for (offset, line) in ["Prepare a cover, a short introduction, and a set of review notes.", "Keep the layout clear and the language straightforward.", "The final document should be easy to read on screen and in print."].enumerated() { text(line, y: CGFloat(453 - offset * 20)) }
    text("Working notes", y: 365, size: 15, bold: true)
    text("Edit this sentence to test a direct PDF text change.", y: 332)
    text("Review the notes on page two and fill the fields on page three.", y: 306)
    if let artwork = CGContext(data: nil, width: 500, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
        artwork.setFillColor(NSColor(calibratedRed: 0.9, green: 0.95, blue: 0.95, alpha: 1).cgColor); artwork.fill(CGRect(x: 0, y: 0, width: 500, height: 100))
        artwork.setFillColor(NSColor.systemTeal.cgColor)
        for index in 0..<6 { artwork.fill(CGRect(x: 26 + index * 76, y: 20, width: 48, height: 20 + index * 8)) }
        if let image = artwork.makeImage() { context.draw(image, in: CGRect(x: 54, y: 154, width: 504, height: 100)) }
    }
    text("Sample artwork — select it in Edit PDF to replace or resize it.", y: 133, size: 10, color: .gray)
    context.endPDFPage()
    header("Review notes", page: 2)
    text("Before the next revision", y: 615, size: 17, bold: true)
    for (offset, line) in ["• Confirm the title and introduction.", "• Check the margins and image placement.", "• Highlight anything that needs a second look.", "• Add comments beside the relevant passage."].enumerated() { text(line, y: CGFloat(573 - offset * 32)) }
    text("A passage to review", y: 388, size: 15, bold: true)
    for (offset, line) in ["A document is most useful when the information is easy to find.", "Use annotations for feedback and direct editing for content changes.", "Keep a copy of the original before making substantial revisions."].enumerated() { text(line, y: CGFloat(350 - offset * 22)) }
    context.endPDFPage()
    header("Approval sheet", page: 3)
    text("Reviewer details", y: 615, size: 17, bold: true)
    text("Name", y: 565); text("Email", y: 475); text("Ready for the next revision", x: 82, y: 393)
    text("Signature", y: 309); text("This is a fictional sample, not a legal agreement.", y: 177, size: 10, color: .gray)
    context.endPDFPage(); context.closePDF()
    guard let document = PDFDocument(data: buffer as Data), let page = document.page(at: 2) else { throw CocoaError(.fileReadCorruptFile) }
    for (name, y) in [("Reviewer name", 522.0), ("Reviewer email", 432.0)] {
        let field = PDFAnnotation(bounds: CGRect(x: 54, y: y, width: 350, height: 30), forType: .widget, withProperties: nil)
        field.widgetFieldType = .text; field.fieldName = name; field.widgetStringValue = ""; field.font = .systemFont(ofSize: 12)
        field.backgroundColor = .white; let border = PDFBorder(); border.lineWidth = 1; field.border = border; page.addAnnotation(field)
    }
    let check = PDFAnnotation(bounds: CGRect(x: 54, y: 387, width: 18, height: 18), forType: .widget, withProperties: nil)
    check.widgetFieldType = .button; check.widgetControlType = .checkBoxControl; check.fieldName = "Ready for revision"; check.buttonWidgetState = .offState; page.addAnnotation(check)
    return document
}

extension AppDelegate {
    @objc func openSampleDocument() {
        do {
            let document = FreePDFDocument(); document.pdf = try makeSampleDocument()
            NSDocumentController.shared.addDocument(document); document.makeWindowControllers(); document.showWindows()
            document.editor?.window?.title = "Sample project brief — FreePDF"
        } catch { Dialogs.error(error) }
    }
}
