# Feature parity and release roadmap

All requested feature groups remain in scope. A feature being on this list is not a claim that it is implemented.

## Implemented preview

- [x] Native PDF reader, search, thumbnails, outline navigation, view modes, printing.
- [x] Text markup, notes, free text, shapes, ink, annotation editing/deletion.
- [x] Page merge/split/extract/reorder/rotate/move/delete/insert/crop.
- [x] Standard form inspector and text-field creation.
- [x] Imported visible signature marks.
- [x] Local OCR and invisible searchable text output.
- [x] Page numbering, watermarking, stamps.
- [x] Text/RTF/image exports, compression, flattening, encrypted copies.
- [x] Raster redaction rebuilding the complete document.
- [x] Raster region replacement with new text.
- [x] Text-only comparison report.
- [x] Native document saving and undo for app-controlled edits.

## Before stable 1.0

- [ ] Expand independent rendering/extraction checks across a public, license-safe PDF corpus.
- [x] macOS 15 Apple Silicon CI: core tests, packaging, and native document smoke test.
- [ ] Verify Intel and macOS 14 compatibility; automated interactive macOS UI regression coverage.
- [ ] Improve current-page annotation/form inspector into a persistent side panel.
- [ ] Drag-to-reposition/resize annotations and signature images; saved signature library.
- [ ] Undo operation deltas and explicit large-file memory benchmarks.
- [x] Recovery snapshots every 30 seconds with encrypted PDF bytes preserved.
- [ ] Forced crash/relaunch and corrupt-recovery tests.
- [x] Transient redaction overlay; document mutations clear potentially stale regions.
- [ ] Persist and remap redaction marks across document edits.
- [ ] Full VoiceOver audit, localization, and keyboard-only interaction verification.
- [ ] Preserve outline destinations through all page mutations.
- [ ] Signed/notarized releases and update distribution if funding is available.

## Advanced feature gates

### Existing PDF text/image editing

- [ ] Evaluate an open-source content-stream engine and dependency licenses.
- [ ] Replace text/image operators without rasterizing pages.
- [ ] Handle embedded/subset fonts, complex scripts, kerning, rotated text, and clipping.
- [ ] Add editor controls and visual regression fixtures before advertising layout fidelity.

Current area replacement is a pixel-based workaround with explicit flattening, not semantic PDF text editing.

### Vector-preserving permanent redaction

- [ ] Remove content operators, overlapping objects, hidden layers, related metadata, and embedded files.
- [ ] Verify with an independent parser and extraction engine.
- [ ] Add adversarial fixtures for cropped content, transparency, rotated text, annotations, and incremental revisions.

Current raster redaction drops the original object graph and metadata entirely, at the cost of document structure and quality.

### Forms, signing, comparison, and batches

- [ ] Form designer for choice, checkbox, radio, validation, and tab order; radio-group semantics.
- [ ] Cryptographic digital signatures, certificate selection, validation, and signed-document mutation detection.
- [ ] Visual page comparison with alignment and side-by-side review.
- [x] Batch OCR and compression with per-file failures and cancellation.
- [ ] Expanded batch export and selectable OCR languages in batch UI.

### Additional scope from the review plan

- [ ] Layout-preserving DOCX/XLSX/PPTX conversion (separate feasibility study).
- [ ] PDF/A and PDF/UA validation and accessibility remediation.
- [ ] Print preflight and production color management.
- [ ] Remote signature workflows and collaboration only if a sustainable free service is feasible.
- [ ] Optional local AI only after model licensing, hardware, and memory evaluation.

## Definition of done

A feature is complete only when it is reachable in the app, handles cancellation/failure, has relevant automated evidence, survives save/reopen where applicable, and its limitations are documented. Do not replace an unsupported operation with a decorative toolbar button.
