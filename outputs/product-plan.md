# Free macOS PDF application — review draft

## Goal and assumptions
Build an independently designed native PDF application for personal use on an Apple Silicon MacBook Air. No subscription, account, server, advertising, or paid PDF SDK. Documents and OCR stay on the Mac. The exact Mac model and installed macOS version must be confirmed before setting the minimum supported OS.

## Product scope
### Release 1: everyday PDF work
- Open multiple documents; zoom, search, select/copy text, thumbnails, document outlines, and print.
- Highlight, underline, strike through, draw, add notes, shapes, and text boxes.
- Merge, split, extract, reorder, rotate, insert, and delete pages.
- Fill standard PDF form fields; add a drawn or imported signature image.
- Create PDFs from images; export pages as images and embedded text as text files.
- Undo/redo, Save As, unsaved-change prompts, recovery, keyboard shortcuts, and dark mode.

### Release 2: additional value
- On-device OCR with a searchable text layer; cancellation, progress, and language selection.
- Add page numbers, watermarks, and stamps.
- Optimize scanned-image PDFs, with a quality preview and an original preserved.
- Open password-protected documents with a supplied password; investigate encrypted output separately.

### Release 3: feasibility-gated advanced features
- True editing of existing PDF text/images: requires an additional content-editing engine, font handling, and layout preservation. Text-box annotations do not satisfy this feature.
- Permanent redaction: requires removal of underlying content and relevant hidden data, with extraction-based verification. A black rectangle is not redaction.
- Document comparison, form creation, and batch workflows.

### Deferred
High-fidelity Word/Excel/PowerPoint conversion; certificate-based digital signatures; remote signature workflows; XFA forms; PDF/A and PDF/UA validation; print-production tools; cloud collaboration and AI services.

## Interface
Native document window: page thumbnails on the left, PDF canvas in the center, contextual properties on the right. Toolbar groups: Read, Annotate, Pages, Fill & Sign, Export. Support drag-and-drop and macOS keyboard conventions. Use an original product name and visual design.

## Technical approach
Swift and SwiftUI for the application, AppKit integration for document lifecycle and PDF views, Apple PDFKit for rendering/selection/annotations/page operations, and Vision for local OCR. Local files are the source of truth; no backend is required. Introduce third-party libraries only after an actual capability gap and a license/maintenance review.

PDFKit supplies core PDF functionality, but is not a complete Acrobat-style content editor. OCR recognition and writing a correct searchable PDF layer are separate tasks. Signatures in the first release are visible marks, not cryptographic signatures.

## Build order and acceptance gates
1. Compatibility and feasibility: confirm hardware/macOS/Xcode; test representative text, scanned, form, encrypted, and large PDFs. Verify annotation, page, and form persistence before committing to architecture.
2. Reader and safe saving: open/search/print, multiple windows, Save As. Originals survive cancellation and failed writes; outputs reopen in Preview.
3. Annotation workflow: add/edit/remove annotations with undo/redo. Saved geometry and text persist across reopen and page rotation.
4. Page workflow: combine/reorder/split/export. Page count, order, dimensions, annotations, and forms remain correct after round trips.
5. Forms and signatures: fill supported fields and place signature images. Saved values render in Preview; unsupported forms produce a clear explanation.
6. First-release polish: image/text export, accessibility, recovery, shortcuts, and large-document responsiveness. Verify complete workflows on the target MacBook Air.
7. OCR prototype then release: coordinate mapping, supported languages, searchable-text output, cancellation, and memory use. Sample scanned pages remain visually intact and findable after reopen.
8. Advanced engine evaluation: prototype existing-content edits and secure redaction before promising either feature. Proceed only after fidelity, correctness, and licensing gates pass.

## Cost and distribution
Use free Apple frameworks and development tools for the personal app. Personal development need not involve a paid PDF service. Broader distribution, signing, notarization, or an App Store release should be costed separately before release. Open-source dependencies require an explicit license review.

## Risks
- PDF variety: maintain a representative fixture collection and cross-viewer verification.
- Data loss: preserve originals, write atomically, and test failed/cancelled saves.
- Scanned-document memory use: process pages incrementally with cancellable work.
- Content editing and redaction complexity: separate feasibility gates and avoid cosmetic substitutes.

## Review questions
1. Which three Acrobat tasks matter most, especially whether replacing existing text is essential?
2. What MacBook Air chip, memory, and macOS version are installed?
3. Is this for personal use or eventual public distribution?

## Sources
- Adobe tools: https://helpx.adobe.com/acrobat/using/explore-acrobat-tools.html
- Apple PDFKit: https://developer.apple.com/documentation/quartz/pdfkit
- Apple Vision OCR: https://developer.apple.com/documentation/vision/recognizing-text-in-images
