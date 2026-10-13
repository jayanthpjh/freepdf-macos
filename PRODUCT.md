# FreePDF

<!-- impeccable:product-schema 1 -->

## Platform

macos

This is a native macOS AppKit application, not a web or mobile interface. The schema is extended to record the user's explicit platform.

## Users

The primary user owns a 2025 MacBook Air and wants a free alternative to paid Acrobat workflows. The user wants the project published openly on GitHub.

## Product Purpose

Read, edit, annotate, organize, fill, and export PDFs locally. Success means useful PDF work without subscriptions, rather than only a minimal viewer.

## Operating Context

Native macOS desktop application; Apple Silicon is the current verified machine. Original documents must remain recoverable. PDFs can contain private information and must not be uploaded for processing.

## Capabilities and Constraints

The user confirmed that both a fuller interface and more editing features are priorities. Existing functionality is recorded in README.md. Native Apple frameworks come first; an additional open-source engine may fill a demonstrated content-editing gap. All outputs need save/reopen tests. Exact Acrobat parity must never be claimed for approximations.

## Brand Commitments

FreePDF is the current independently named product. Adobe Acrobat's professional document workspace is the user's functional/interface reference. WordCraft was supplied as an open-source architectural reference. Do not copy proprietary logos, assets, or code.

## Evidence on Hand

Working native application, generated test fixtures, automated core tests, native document tests, and a newly verified visible-window startup test. Current source: Sources/FreePDF and Sources/FreePDFCore.

## Product Principles

- Documents stay local; no telemetry, accounts, paid SDKs, or cloud processing.
- Common tools must be visible and understandable, rather than buried in menus.
- Editing existing content, annotations, flattening, and signing are distinct workflows.
- Preserve originals and make quality/security tradeoffs clear.
- Keep the open-source feature matrix honest.
