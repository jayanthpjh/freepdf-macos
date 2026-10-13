# Implementation plan and current state

The project is FreePDF, a native open-source macOS PDF workbench. The original scope draft is in ../outputs/product-plan.md; the current feature matrix is in ../README.md and the remaining parity work is in ../ROADMAP.md.

Implemented: reader/window/document foundation, annotations, page operations, forms, visible signature images, OCR, raster redaction and replacement, text comparison, PDF/image/text exports, encryption/compression, recovery, and batch OCR/compression. The native core and document smoke tests provide initial verification.

Not complete: full content-stream editing, visual diff, layout-preserving Office conversion, cryptographic signatures, comprehensive accessibility/compatibility/UI QA, and production release hardening. These remain explicit roadmap items.

Reference projects: WordCraft and its PdfCraft sibling, reviewed as architectural/product references; no source or assets copied.
