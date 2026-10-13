import AppKit
import PDFKit
import CoreText

/// Rebuilds PDFs from rendered pixels. The output contains no source objects or metadata.
public enum RasterPDF {
    public static func image(_ page: PDFPage, scale: CGFloat = 2, covering regions: [CGRect] = [], replacement: String? = nil) throws -> CGImage {
        let box = page.bounds(for: .cropBox)
        let rotated = abs(page.rotation % 180) == 90
        let size = CGSize(width: rotated ? box.height : box.width, height: rotated ? box.width : box.height)
        guard scale.isFinite, scale > 0, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, size.width * size.height * scale * scale <= 40_000_000,
              let ref = page.pageRef else { throw PDFError.imageTooLarge }
        let width = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PDFError.imageTooLarge }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let transform = ref.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true)
        context.concatenate(transform)
        context.drawPDFPage(ref)
        for annotation in page.annotations where annotation.shouldDisplay {
            annotation.draw(with: .cropBox, in: context)
        }
        for region in regions {
            guard !region.isNull, region.width > 0, region.height > 0, box.contains(region) else { throw PDFError.invalidPages }
            context.setFillColor(CGColor(gray: replacement == nil ? 0 : 1, alpha: 1))
            context.fill(region)
            if let replacement, !replacement.isEmpty {
                let font = CTFontCreateWithName("Helvetica" as CFString, min(18, region.height * 0.65), nil)
                let text = NSAttributedString(string: replacement, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)])
                let line = CTLineCreateWithAttributedString(text)
                context.saveGState()
                context.clip(to: region)
                context.textMatrix = .identity
                context.textPosition = CGPoint(x: region.minX + 2, y: region.minY + region.height * 0.22)
                CTLineDraw(line, context)
                context.restoreGState()
            }
        }
        guard let image = context.makeImage() else { throw PDFError.invalidDocument }
        return image
    }

    public static func page(image: CGImage, size: CGSize, words: [(String, CGRect)] = []) throws -> PDFPage {
        let buffer = NSMutableData()
        var box = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: buffer), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw PDFError.invalidDocument }
        context.beginPDFPage(nil)
        context.draw(image, in: box)
        for (string, rect) in words where !string.isEmpty && rect.height > 0 {
            let font = CTFontCreateWithName("Helvetica" as CFString, rect.height * 0.85, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.minY + rect.height * 0.15)
            context.scaleBy(x: width > 0 ? rect.width / width : 1, y: 1)
            context.textMatrix = .identity
            context.textPosition = .zero
            context.setTextDrawingMode(.invisible)
            CTLineDraw(line, context)
            context.restoreGState()
        }
        context.endPDFPage(); context.closePDF()
        guard let page = PDFDocument(data: buffer as Data)?.page(at: 0) else { throw PDFError.invalidDocument }
        return page
    }

    public static func redact(_ source: PDFDocument, regions: [Int: [CGRect]], scale: CGFloat = 2, replacement: String? = nil,
                              progress: Progress? = nil) throws -> PDFDocument {
        guard !source.isLocked else { throw PDFError.locked }
        guard !regions.isEmpty, regions.keys.allSatisfy({ $0 >= 0 && $0 < source.pageCount }) else { throw PDFError.invalidPages }
        let output = PDFDocument()
        progress?.totalUnitCount = Int64(source.pageCount)
        for index in 0..<source.pageCount {
            if progress?.isCancelled == true { throw CancellationError() }
            try autoreleasepool {
                guard let original = source.page(at: index) else { throw PDFError.invalidDocument }
                let image = try image(original, scale: scale, covering: regions[index] ?? [], replacement: replacement)
                let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
                output.insert(try page(image: image, size: size), at: output.pageCount)
            }
            progress?.completedUnitCount += 1
        }
        return output
    }
}
