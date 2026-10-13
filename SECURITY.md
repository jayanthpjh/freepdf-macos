# Security and privacy

FreePDF uses local Apple frameworks. It has no network client, telemetry, account system, or backend. PDF button scripts are not executed by the form inspector. External document links may be handled by macOS/PDFKit; do not follow links in untrusted PDFs.

PDF files are untrusted parser input. Keep macOS patched. This preview is ad-hoc signed and is not currently App Sandbox hardened. Do not use it as a replacement for an isolated document-analysis environment.

Exports write atomically. Split exports use a new output folder. Password export requires confirmation and uses a separately generated owner password. The app retains a supplied unlock password only in memory for encrypted undo and background operations. Passwords are not written to disk. Recovery snapshots preserve PDF encryption and live under the application support folder, with a private directory and owner-only files. Existing encryption preservation is covered by a round-trip test; broader permissions/signature validation remains a release task.

Raster redaction creates a new document from pixels, dropping the original PDF object graph, metadata, annotations, attachments, and text layer. It does not preserve accessibility or signatures. Incorrectly selected rectangles can still leave visible sensitive content. Examine the result. The original stays on disk and may exist in backups; redacting an output does not erase original files.

For a potential vulnerability, report privately to the repository owner through GitHub's private vulnerability reporting when enabled. Do not attach sensitive PDFs to public issues.
