# FreePDF for macOS

[![macOS build and tests](https://github.com/jayanthpjh/freepdf-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/jayanthpjh/freepdf-macos/actions/workflows/ci.yml)

A free, offline, native PDF workbench for macOS. Built with Swift, AppKit, PDFKit, and Vision. No accounts, telemetry, subscriptions, cloud backend, or paid PDF SDK. Direct content editing uses bundled open-source PDFium.

**Status: early development preview, not full Acrobat parity.** This project is independently implemented. It is not affiliated with Adobe or Apple.

## Features

| Workflow | Current implementation |
| --- | --- |
| Read | Native PDF rendering, text selection/copy, search on Return, page thumbnails, outline navigation, zoom, single/continuous/two-page viewing, printing |
| Edit PDF | Select existing top-level text/image objects; replace text with a standard font, move/resize/delete objects, replace images; save without rasterizing the page |
| Workspace | Read, Edit PDF, Annotate, Pages, Fill & Sign, Scan & OCR, Export modes; visible tool sidebar, persistent inspector, drag-to-reorder thumbnails, fictional sample document |
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

Advanced typography and grouped content editing, layout-preserving Office conversion, cryptographic signatures, full form design, visual comparison, and recovery hardening are tracked in [ROADMAP.md](ROADMAP.md).

## Requirements

- macOS 14 or later (minimum target; verified on Apple Silicon, macOS 15 in GitHub CI and macOS 27.0.1 locally).
- Xcode or the Swift toolchain, Swift 5.10 or later.
- First build downloads a checksum-pinned PDFium binary; subsequent use is fully offline. No API keys.

## Build and run

```sh
./scripts/build-app.sh
open outputs/FreePDF.app
```

The script builds a release `.app` and ad-hoc signs it for local use. The downloadable preview is not Developer ID signed or notarized. Public distribution with notarization is a separate release task.

To work on the code, open `Package.swift` in Xcode. To run tests:

```sh
./scripts/bootstrap-pdfium.sh
swift test
outputs/FreePDF.app/Contents/MacOS/FreePDF --smoke-test "$PWD/work"
outputs/FreePDF.app/Contents/MacOS/FreePDF --startup-test
```

Vision integration tests require access to macOS system services. Restricted execution sandboxes can fail even when the app runs normally; do not silently skip these tests.

## Quick workflow

1. Open a PDF with File → Open or the Open button.
2. Choose Edit PDF and click existing text or an image. Use the inspector to apply text, geometry, or image changes. Standard fonts support basic Latin text; original subset fonts can reject new characters.
3. Select text for highlight/underline/strike. Choose a drawing tool and drag on a page to add other annotations.
4. Use Pages for page operations and Tools for OCR, stamps, and comparison.
5. Use Fill form fields to edit the current page's widgets with undo support.
6. For redaction, choose Redact area, mark every area, then Apply redactions. Save the resulting new document separately.
7. Save edits with ⌘S or use Save As with ⇧⌘S. OCR and redaction results are new unsaved documents.

Direct editing currently supports top-level PDF text and image objects. Text does not automatically reflow or match embedded fonts. Grouped Form XObjects, complex scripts, clipping, and advanced typography remain limited. Editing normalizes path colors on the edited page to device RGB to preserve screen rendering; original ICC/spot print color spaces are not retained for those paths. Annotation text boxes and raster area replacement are separate tools. Visible signature images are not cryptographic signatures. Use File → Open sample document to explore safely.

## Verification

Automated checks cover PDF round trips, OCR recognition and searchability, encrypted exports and serialization, form values, batch isolation, and recovery bytes. The packaged app smoke test checks native window layout, insertion, undo/redo, encrypted undo, safe saving, and reverting to saved files. Real startup regression checks verify a registered visible window. Saved/reopened direct text edits, image replacement, movement, deletion, and encryption preservation are also tested. The initial missing-window defect has been fixed and window visibility confirmed in the desktop inspector; broader interactive QA is still required.

## Architecture

- `Sources/FreePDFCore`: PDF page operations, validated page-range parsing, bounded raster rendering, raster redaction/replacement, local OCR, and serialized PDFium content editing.
- `Sources/FreePDF`: native document lifecycle, canvas interactions, command catalog, window layout, annotations/forms, exports, and background tasks.
- `Tests/FreePDFCoreTests`: round-trip, encryption, form, OCR, geometry, and data-removal checks.
- `scripts`: reproducible `.app` packaging.

Full-document undo snapshots are simple but can use substantial memory on large PDFs. Raster rendering is capped at 40 million pixels and 20,000 pixels on each axis. OCR/redaction work page-by-page; cancellation is checked between pages and after recognition.

## References and licensing

[WordCraft](https://github.com/storytold/wordcraft) was supplied as a reference for independent implementation, offline operation, modular architecture, and transparent parity tracking. Its README also led to [PdfCraft](https://github.com/storytold/pdfcraft), a relevant comparative project. No code or assets from either project are included.

Bundled PDFium and its dependencies retain their own licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the notices inside the app.

FreePDF's original source is [MIT licensed](LICENSE). System frameworks and SF Symbols remain subject to Apple's terms. Adobe Acrobat is a trademark of Adobe; the name is used only for feature comparison.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).
