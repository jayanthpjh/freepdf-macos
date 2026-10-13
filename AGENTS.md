# FreePDF engineering guidelines

This is a native macOS application. Use Swift, AppKit, PDFKit, Vision, and Core Graphics before introducing third-party packages. Keep PDF processing in FreePDFCore and UI/document lifecycle in FreePDF.

Do not claim Acrobat parity for approximations. Text-box annotations, raster region replacement, semantic content-stream editing, visible signature images, and cryptographic signatures are distinct features. Document user-visible limitations.

Preserve original files. OCR/redaction produce new documents. Redaction outputs must contain no original object graph or hidden text/metadata; appearance alone is insufficient. Passwords must never be persisted or logged. Recovery snapshots must preserve encryption.

For every behavioral change, run `swift test` and `./scripts/build-app.sh`. For document/window changes, run `outputs/FreePDF.app/Contents/MacOS/FreePDF --smoke-test "$PWD/work"`. Add tests for saved/reopened output. Update README/ROADMAP honestly. Never skip a failed OCR test due to environment restrictions; run with the required macOS service access and report the limitation.

No telemetry, accounts, cloud uploads, paid SDKs, or remote processing without an explicit scope change from the user. Test with generated fixtures; never publish private PDFs.
