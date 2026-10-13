import Foundation
import CoreGraphics
import PDFKit
import CPDFium

public struct PDFContentObject: Identifiable, Equatable {
    public let id: Int
    public let kind: Kind
    public let text: String
    public let bounds: CGRect
    public let fontSize: CGFloat
    public enum Kind: Equatable { case text, image }
}

/// Edits PDF content objects; no white-box overlays or whole-page raster replacement.
/// PDFium is serialized because its API is not thread safe. Source bytes are never written in place.
public enum ContentEditing {
    public enum Font: String, CaseIterable { case original = "Original font", helvetica = "Helvetica", times = "Times-Roman", courier = "Courier" }
    public enum EditError: LocalizedError {
        case unsupportedCharacters
        public var errorDescription: String? { "The chosen font cannot represent all replacement characters. Choose another font or use a text annotation for complex scripts." }
    }
    private static let lock = NSLock()
    private static let initialized: Void = { FPDF_InitLibrary() }()
    private static func withDocument<T>(_ data: Data, password: String?, page index: Int, _ work: (FPDF_DOCUMENT, FPDF_PAGE) throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        _ = initialized
        return try data.withUnsafeBytes { bytes in
            guard let document = FPDF_LoadMemDocument64(bytes.baseAddress, data.count, password) else { throw PDFError.invalidDocument }
            defer { FPDF_CloseDocument(document) }
            guard index >= 0, index < FPDF_GetPageCount(document), let page = FPDF_LoadPage(document, Int32(index)) else { throw PDFError.invalidPages }
            defer { FPDF_ClosePage(page) }
            return try work(document, page)
        }
    }
    public static func objects(in data: Data, page index: Int, password: String? = nil) throws -> [PDFContentObject] {
        try withDocument(data, password: password, page: index) { _, page in
            guard let textPage = FPDFText_LoadPage(page) else { throw PDFError.invalidDocument }
            defer { FPDFText_ClosePage(textPage) }
            var objects: [PDFContentObject] = []
            let count = FPDFPage_CountObjects(page)
            guard count >= 0 else { throw PDFError.invalidDocument }
            for index in 0..<min(count, 5000) {
                guard let object = FPDFPage_GetObject(page, index) else { continue }
                let type = FPDFPageObj_GetType(object)
                guard type == FPDF_PAGEOBJ_TEXT || type == FPDF_PAGEOBJ_IMAGE else { continue }
                var left: Float = 0, bottom: Float = 0, right: Float = 0, top: Float = 0
                guard FPDFPageObj_GetBounds(object, &left, &bottom, &right, &top) != 0 else { continue }
                let bounds = CGRect(x: CGFloat(left), y: CGFloat(bottom), width: CGFloat(right - left), height: CGFloat(top - bottom))
                guard [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy({ $0.isFinite && abs($0) < 100000 }) else { continue }
                var text = "", size: Float = 0
                if type == FPDF_PAGEOBJ_TEXT {
                    let bytes = FPDFTextObj_GetText(object, textPage, nil, 0)
                    guard bytes > 0, bytes < 1_000_000 else { continue }
                    var buffer = [UInt16](repeating: 0, count: Int(bytes) / 2)
                    _ = buffer.withUnsafeMutableBufferPointer { FPDFTextObj_GetText(object, textPage, $0.baseAddress, bytes) }
                    text = String(decoding: buffer.prefix { $0 != 0 }, as: UTF16.self)
                    _ = FPDFTextObj_GetFontSize(object, &size)
                    var matrix = FS_MATRIX()
                    if FPDFPageObj_GetMatrix(object, &matrix) != 0 { size *= hypot(matrix.c, matrix.d) }
                }
                objects.append(PDFContentObject(id: Int(index), kind: type == FPDF_PAGEOBJ_TEXT ? .text : .image, text: text, bounds: bounds, fontSize: CGFloat(size)))
            }
            return objects
        }
    }
    public static func replaceText(in data: Data, page index: Int, object id: Int, text: String, fontSize: CGFloat? = nil, font: Font = .helvetica, password: String? = nil) throws -> Data {
        guard !text.isEmpty, !text.contains("\0"), text.utf16.count < 10000 else { throw PDFError.noText }
        return try withDocument(data, password: password, page: index) { document, page in
            guard id >= 0, id < FPDFPage_CountObjects(page), let object = FPDFPage_GetObject(page, Int32(id)), FPDFPageObj_GetType(object) == FPDF_PAGEOBJ_TEXT else { throw PDFError.invalidPages }
            var size: Float = 16
            _ = FPDFTextObj_GetFontSize(object, &size)
            if let fontSize {
                guard fontSize.isFinite, fontSize > 0, fontSize <= 200 else { throw PDFError.invalidDocument }
                var matrix = FS_MATRIX()
                guard FPDFPageObj_GetMatrix(object, &matrix) != 0 else { throw PDFError.invalidDocument }
                let scale = hypot(matrix.c, matrix.d)
                guard scale > 0 else { throw PDFError.invalidDocument }
                size = Float(fontSize) / scale
            }
            var editable = object
            if font != .original {
                var matrix = FS_MATRIX()
                guard FPDFPageObj_GetMatrix(object, &matrix) != 0,
                      let replacement = FPDFPageObj_NewTextObj(document, font.rawValue, size) else { throw PDFError.invalidDocument }
                var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, alpha: UInt32 = 255
                _ = FPDFPageObj_GetFillColor(object, &r, &g, &b, &alpha)
                _ = FPDFPageObj_SetFillColor(replacement, r, g, b, alpha)
                _ = FPDFPageObj_SetMatrix(replacement, &matrix)
                _ = FPDFTextObj_SetTextRenderMode(replacement, FPDFTextObj_GetTextRenderMode(object))
                guard FPDFPage_RemoveObject(page, object) != 0 else { FPDFPageObj_Destroy(replacement); throw PDFError.invalidDocument }
                FPDFPageObj_Destroy(object)
                guard FPDFPage_InsertObjectAtIndex(page, replacement, id) != 0 else { FPDFPageObj_Destroy(replacement); throw PDFError.invalidDocument }
                editable = replacement
            } else { _ = FPDFTextObj_SetFontSize(editable, size) }
            let unicode = Array(text.utf16) + [0]
            guard unicode.withUnsafeBufferPointer({ FPDFText_SetText(editable, $0.baseAddress) }) != 0 else { throw PDFError.invalidDocument }
            guard let textPage = FPDFText_LoadPage(page) else { throw PDFError.invalidDocument }
            let length = FPDFTextObj_GetText(editable, textPage, nil, 0)
            var encoded = [UInt16](repeating: 0, count: max(1, Int(length) / 2))
            _ = encoded.withUnsafeMutableBufferPointer { FPDFTextObj_GetText(editable, textPage, $0.baseAddress, length) }
            FPDFText_ClosePage(textPage)
            guard String(decoding: encoded.prefix { $0 != 0 }, as: UTF16.self) == text else { throw EditError.unsupportedCharacters }
            let result = try save(document, page: page)
            guard let reopened = PDFDocument(data: result) else { throw PDFError.invalidDocument }
            if reopened.isLocked { guard let password, reopened.unlock(withPassword: password) else { throw PDFError.locked } }
            // Validate the edited object itself after serialization. A matching
            // string elsewhere on the page cannot prove this font saved its glyphs.
            let savedObjectContent: (String, CGRect) = try result.withUnsafeBytes { bytes in
                guard let savedDocument = FPDF_LoadMemDocument64(bytes.baseAddress, result.count, password) else { throw PDFError.invalidDocument }
                defer { FPDF_CloseDocument(savedDocument) }
                guard let savedPage = FPDF_LoadPage(savedDocument, Int32(index)) else { throw PDFError.invalidPages }
                defer { FPDF_ClosePage(savedPage) }
                guard let savedObject = FPDFPage_GetObject(savedPage, Int32(id)),
                      FPDFPageObj_GetType(savedObject) == FPDF_PAGEOBJ_TEXT,
                      let savedTextPage = FPDFText_LoadPage(savedPage) else { throw PDFError.invalidDocument }
                defer { FPDFText_ClosePage(savedTextPage) }
                let byteCount = FPDFTextObj_GetText(savedObject, savedTextPage, nil, 0)
                guard byteCount > 0, byteCount < 1_000_000 else { throw EditError.unsupportedCharacters }
                var savedCharacters = [UInt16](repeating: 0, count: Int(byteCount) / 2)
                _ = savedCharacters.withUnsafeMutableBufferPointer { FPDFTextObj_GetText(savedObject, savedTextPage, $0.baseAddress, byteCount) }
                var left: Float = 0, bottom: Float = 0, right: Float = 0, top: Float = 0
                guard FPDFPageObj_GetBounds(savedObject, &left, &bottom, &right, &top) != 0 else { throw PDFError.invalidDocument }
                return (String(decoding: savedCharacters.prefix { $0 != 0 }, as: UTF16.self), CGRect(x: CGFloat(left), y: CGFloat(bottom), width: CGFloat(right - left), height: CGFloat(top - bottom)))
            }
            guard savedObjectContent.0 == text,
                  reopened.page(at: index)?.selection(for: savedObjectContent.1.insetBy(dx: -0.5, dy: -0.5))?.string == text else { throw EditError.unsupportedCharacters }
            return result
        }
    }
    private static func save(_ document: FPDF_DOCUMENT, page: FPDF_PAGE) throws -> Data {
        // PDFium's content writer does not retain every imported color-space
        // resource when rewriting a page. Resolve path colors to device RGB
        // before generation so calibrated-gray backgrounds do not become black.
        for index in 0..<FPDFPage_CountObjects(page) {
            guard let object = FPDFPage_GetObject(page, index), FPDFPageObj_GetType(object) == FPDF_PAGEOBJ_PATH else { continue }
            var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, alpha: UInt32 = 255
            if FPDFPageObj_GetFillColor(object, &r, &g, &b, &alpha) != 0 { _ = FPDFPageObj_SetFillColor(object, r, g, b, alpha) }
            if FPDFPageObj_GetStrokeColor(object, &r, &g, &b, &alpha) != 0 { _ = FPDFPageObj_SetStrokeColor(object, r, g, b, alpha) }
        }
        guard FPDFPage_GenerateContent(page) != 0 else { throw PDFError.invalidDocument }
        var count = 0
        guard let bytes = FreePDF_SaveCopy(document, &count) else { throw PDFError.invalidDocument }
        defer { FreePDF_FreeBuffer(bytes) }
        return Data(bytes: bytes, count: count)
    }
    public static func deleteObject(in data: Data, page index: Int, object id: Int, password: String? = nil) throws -> Data {
        try withDocument(data, password: password, page: index) { document, page in
            guard id >= 0, id < FPDFPage_CountObjects(page), let object = FPDFPage_GetObject(page, Int32(id)), FPDFPage_RemoveObject(page, object) != 0 else { throw PDFError.invalidPages }
            FPDFPageObj_Destroy(object)
            return try save(document, page: page)
        }
    }
    public static func moveObject(in data: Data, page index: Int, object id: Int, to rect: CGRect, password: String? = nil) throws -> Data {
        guard [rect.minX, rect.minY, rect.width, rect.height].allSatisfy({ $0.isFinite && abs($0) < 100000 }), rect.width > 0, rect.height > 0 else { throw PDFError.invalidPages }
        return try withDocument(data, password: password, page: index) { document, page in
            guard id >= 0, id < FPDFPage_CountObjects(page), let object = FPDFPage_GetObject(page, Int32(id)) else { throw PDFError.invalidPages }
            var left: Float = 0, bottom: Float = 0, right: Float = 0, top: Float = 0
            guard FPDFPageObj_GetBounds(object, &left, &bottom, &right, &top) != 0, right > left, top > bottom else { throw PDFError.invalidPages }
            let sx = Double(rect.width) / Double(right - left), sy = Double(rect.height) / Double(top - bottom)
            FPDFPageObj_Transform(object, sx, 0, 0, sy, Double(rect.minX) - sx * Double(left), Double(rect.minY) - sy * Double(bottom))
            return try save(document, page: page)
        }
    }
    public static func replaceImage(in data: Data, page index: Int, object id: Int, image: CGImage, password: String? = nil) throws -> Data {
        guard image.width > 0, image.height > 0, image.width <= 20000, image.height <= 20000, image.width * image.height <= 40_000_000 else { throw PDFError.imageTooLarge }
        return try withDocument(data, password: password, page: index) { document, page in
            guard id >= 0, id < FPDFPage_CountObjects(page), let object = FPDFPage_GetObject(page, Int32(id)), FPDFPageObj_GetType(object) == FPDF_PAGEOBJ_IMAGE,
                  let bitmap = FPDFBitmap_Create(Int32(image.width), Int32(image.height), 1) else { throw PDFError.invalidPages }
            defer { FPDFBitmap_Destroy(bitmap) }
            let stride = Int(FPDFBitmap_GetStride(bitmap))
            guard let bytes = FPDFBitmap_GetBuffer(bitmap), let context = CGContext(data: bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else { throw PDFError.invalidDocument }
            context.clear(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let pixels = bytes.assumingMemoryBound(to: UInt8.self)
            for y in 0..<image.height { for x in 0..<image.width {
                let offset = y * stride + x * 4, alpha = Int(pixels[offset + 3])
                if alpha > 0 && alpha < 255 { for channel in 0..<3 { pixels[offset + channel] = UInt8(min(255, Int(pixels[offset + channel]) * 255 / alpha)) } }
            } }
            guard FPDFImageObj_SetBitmap(nil, 0, object, bitmap) != 0 else { throw PDFError.invalidDocument }
            return try save(document, page: page)
        }
    }

}
