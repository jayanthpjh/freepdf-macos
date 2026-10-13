# FreePDF for macOS

A free, offline, native PDF workbench for macOS. Built with Swift, AppKit, PDFKit, and Vision. No accounts, telemetry, subscriptions, cloud backend, or third-party PDF SDK.

**Status: early development preview, not full Acrobat parity.** This project is independently implemented. It is not affiliated with Adobe or Apple.

## Features

| Workflow | Current implementation |
| --- | --- |
| Read | Native PDF rendering, text selection/copy, search on Return, page thumbnails, outline navigation, zoom, single/continuous/two-page viewing, printing |
| Annotate | Highlight/underline/strike selected text; drag to add text, notes, rectangles, ellipses, and ink; choose colors/font sizes; edit/delete annotations |
| Organize | Merge/insert PDFs and images; blank pages; rotate, crop, reorder, move, delete, extract, and split pages; add bookmarks |
| Forms | Inspect/fill standard text, choice, and checkbox fields on the current page; create text fields; XFA and PDF button scripts are unsupported |
| Sign | Place an imported signature image near the bottom of the current page; flattens that page; no certificate signature |
| OCR | Local Vision recognition of image-only pages; language selection; searchable output; progress and cancellation; existing text pages preserved |
| Decorate | Page numbers, watermarks, stamps |
| Export | PNG, plain text, RTF, extracted PDFs, individual-page PDFs, flattened/compressed PDFs, password-protected copies |
| Redact | Mark rectangles, then create a new rasterized document without source text, annotations, attachments, bookmarks, or source metadata |
| Replace area | Erase a rectangle and draw replacement text in a new rasterized copy; does not reflow existing PDF text or match embedded fonts |
| Compare | Export a line-based text comparison; visual/layout comparison is not implemented |
| Document safety | Native Save/Save As and unsaved-change prompts; undo/redo including encrypted snapshots; recovery checkpoints every 30 seconds; atomic exports; OCR/redaction produce new copies |
| Batch | Multiple-file OCR (English) and compression with cancellation, separate outputs, and a per-file report |

Raster redaction and area replacement intentionally flatten the **whole document**. Searchability, accessibility tags, editable forms, vectors, and digital signatures are lost. A preview is not a production security certification. Inspect every sensitive output before sharing. Pending redaction rectangles are transient overlays and are not stored in the original PDF. Document edits clear the marks to avoid applying them to the wrong page.

Advanced content-stream editing, layout-preserving Office conversion, cryptographic signatures, full form design, visual comparison, and recovery hardening are tracked in [ROADMAP.md](ROADMAP.md).

## Requirements

- macOS 14 or later (minimum target; currently verified on Apple Silicon, macOS 27.0.1).
- Xcode or the Swift toolchain, Swift 5.10 or later.
- No external packages or API keys.

## Build and run

```sh
./scripts/build-app.sh
open outputs/FreePDF.app
```

The script builds a release `.app` and ad-hoc signs it for local use. The downloadable preview is not Developer ID signed or notarized. Public distribution with notarization is a separate release task.

To work on the code, open `Package.swift` in Xcode. To run tests:

```sh
swift test
outputs/FreePDF.app/Contents/MacOS/FreePDF --smoke-test "$PWD/work"
```

Vision integration tests require access to macOS system services. Restricted execution sandboxes can fail even when the app runs normally; do not silently skip these tests.

## Quick workflow

1. Open a PDF with File → Open or the Open button.
2. Select text for highlight/underline/strike. Choose a drawing tool and drag on a page to add other annotations.
3. Use Pages for page operations and Tools for OCR, stamps, and comparison.
4. Use Fill form fields to edit the current page's widgets with undo support.
5. For redaction, choose Redact area, mark every area, then Apply redactions. Save the resulting new document separately.
6. Save edits with ⌘S or use Save As with ⇧⌘S. OCR and redaction results are new unsaved documents.

## Verification

Automated checks cover PDF round trips, OCR recognition and searchability, encrypted exports and serialization, form values, batch isolation, and recovery bytes. The packaged app smoke test checks native window layout, insertion, undo/redo, encrypted undo, and saving. Live pointer/keyboard UI inspection could not be completed because the desktop inspection service timed out; full interactive QA is still required.

## Architecture

- `Sources/FreePDFCore`: PDF page operations, validated page-range parsing, bounded raster rendering, raster redaction/replacement, and local OCR.
- `Sources/FreePDF`: native document lifecycle, canvas interactions, command catalog, window layout, annotations/forms, exports, and background tasks.
- `Tests/FreePDFCoreTests`: round-trip, encryption, form, OCR, geometry, and data-removal checks.
- `scripts`: reproducible `.app` packaging.

Full-document undo snapshots are simple but can use substantial memory on large PDFs. Raster rendering is capped at 40 million pixels and 20,000 pixels on each axis. OCR/redaction work page-by-page; cancellation is checked between pages and after recognition.

## References and licensing

[WordCraft](https://github.com/storytold/wordcraft) was supplied as a reference for independent implementation, offline operation, modular architecture, and transparent parity tracking. Its README also led to [PdfCraft](https://github.com/storytold/pdfcraft), a relevant comparative project. No code or assets from either project are included.

FreePDF's original source is [MIT licensed](LICENSE). System frameworks and SF Symbols remain subject to Apple's terms. Adobe Acrobat is a trademark of Adobe; the name is used only for feature comparison.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
