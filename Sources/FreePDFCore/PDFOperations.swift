import AppKit
import PDFKit

public enum PDFError: LocalizedError {
    case invalidDocument, invalidPages, locked, noText, imageTooLarge
    public var errorDescription: String? {
        switch self {
        case .invalidDocument: return "The PDF could not be read or written."
        case .invalidPages: return "Enter valid page numbers, for example 1-3,5. Keep at least one page."
        case .locked: return "Unlock this document first."
        case .noText: return "No selectable text was found. Use OCR on scanned pages first."
        case .imageTooLarge: return "This page exceeds the safe rendering limit. Reduce the resolution or page dimensions."
        }
    }
}

public enum PDFOperations {
    public static func pageIndices(_ expression: String, count: Int) throws -> [Int] {
        var result: [Int] = []
        for part in expression.split(separator: ",", omittingEmptySubsequences: false) {
            let ends = part.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(ends.count), let first = Int(ends[0]), first > 0, first <= count else { throw PDFError.invalidPages }
            let last = ends.count == 2 ? Int(ends[1]) : first
            guard let last, last >= first, last <= count else { throw PDFError.invalidPages }
            for page in first...last {
                guard !result.contains(page - 1) else { throw PDFError.invalidPages }
                result.append(page - 1)
            }
        }
        guard !result.isEmpty else { throw PDFError.invalidPages }
        return result
    }

    public static func extract(_ source: PDFDocument, indices: [Int]) throws -> PDFDocument {
        guard !source.isLocked else { throw PDFError.locked }
        guard !indices.isEmpty, indices.allSatisfy({ $0 >= 0 && $0 < source.pageCount }) else { throw PDFError.invalidPages }
        let output = PDFDocument()
        for index in indices {
            guard let page = source.page(at: index)?.copy() as? PDFPage else { throw PDFError.invalidDocument }
            output.insert(page, at: output.pageCount)
        }
        return output
    }

    public static func movePages(_ document: PDFDocument, indices: [Int], before destination: Int) throws {
        let sorted = indices.sorted()
        guard !document.isLocked, !sorted.isEmpty, Set(sorted).count == sorted.count,
              sorted.allSatisfy({ $0 >= 0 && $0 < document.pageCount }), destination >= 0, destination <= document.pageCount else { throw PDFError.invalidPages }
        let pages = try sorted.map { index -> PDFPage in guard let page = document.page(at: index) else { throw PDFError.invalidPages }; return page }
        let insertion = destination - sorted.filter { $0 < destination }.count
        for index in sorted.reversed() { document.removePage(at: index) }
        for (offset, page) in pages.enumerated() { document.insert(page, at: insertion + offset) }
    }

    public static func data(_ document: PDFDocument) throws -> Data {
        guard !document.isLocked, document.pageCount > 0, let data = document.dataRepresentation() else { throw PDFError.invalidDocument }
        return data
    }

    public static func blankPage() throws -> PDFPage {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw PDFError.invalidDocument }
        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()
        guard let page = PDFDocument(data: data as Data)?.page(at: 0) else { throw PDFError.invalidDocument }
        return page
    }
}
