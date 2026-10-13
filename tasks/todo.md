# Ordered implementation checklist

Each task depends on the preceding foundation; criteria and verification follow.

- [ ] Confirm compatibility and PDFKit feasibility. Criteria: target OS recorded; representative PDFs load; annotations/forms/page changes survive saving. Verify with sample files in the app and Preview.
- [ ] Build reader and document lifecycle. Criteria: open/search/print work; multiple documents work; safe saves preserve originals. Verify round trips and write failure/cancellation.
- [ ] Add annotations and undo. Criteria: create/edit/delete work; undo/redo work; geometry persists. Verify reopened files, including rotated pages.
- [ ] Checkpoint: reader and annotations operate reliably end to end.
- [ ] Add page operations. Criteria: merge/split/reorder work; page attributes survive; outputs reopen. Verify counts/order and annotations/forms.
- [ ] Add form filling and signature marks. Criteria: supported fields persist; signatures remain positioned; unsupported forms are identified. Verify in Preview.
- [ ] Add image/text export. Criteria: selected pages export correctly; image imports preserve orientation; text extraction reports image-only documents accurately. Verify exported files.
- [ ] Checkpoint: everyday PDF workflows complete.
- [ ] Polish accessibility and recovery. Criteria: keyboard/VoiceOver work; recovery restores unsaved edits; large-document work remains cancellable. Verify on the target Mac.
- [ ] Prototype OCR. Criteria: coordinate mapping is correct; searchable layer survives reopen; page appearance stays intact. Verify representative scans and text search.
- [ ] Add OCR progress/languages/cancellation. Criteria: supported languages are exposed; cancellation is safe; memory remains bounded. Verify multipage scans on target hardware.
- [ ] Checkpoint: review OCR accuracy and first-release readiness.
- [ ] Evaluate content-editing/redaction engines. Criteria: license fits intended distribution; editing preserves representative layouts; redaction removes underlying data. Verify extraction and cross-viewer rendering before implementation approval.
