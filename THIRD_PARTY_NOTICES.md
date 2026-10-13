# Third-party notices

FreePDF bundles the non-V8 PDFium build from [pdfium-binaries chromium/8100](https://github.com/bblanchon/pdfium-binaries/releases/tag/chromium/8100). The distribution is MIT licensed; PDFium uses a BSD-style license and includes separately licensed dependencies.

The build downloads architecture-specific archives and checks pinned SHA-256 digests in `scripts/bootstrap-pdfium.sh`. Full upstream notices are copied into `FreePDF.app/Contents/Resources/Licenses/PDFium`, including the binary distribution license. They must accompany redistributed builds. PDFium source and licensing are maintained at [the upstream project](https://pdfium.googlesource.com/pdfium/).

PDFium processes content locally. This non-V8 build does not run PDF JavaScript. No document is uploaded by FreePDF.
