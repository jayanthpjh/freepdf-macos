# Contributing

Open an issue describing a concrete PDF workflow or failure before proposing a substantial change. Include macOS/CPU details and a minimal PDF fixture only when you have permission to share it. Never submit private documents or credentials.

Build with `./scripts/build-app.sh`, run `swift test`, and manually verify changed workflows in the packaged app and Apple Preview. Add regression tests that validate saved output, not only in-memory values. Keep app UI separate from PDF operations and avoid dependencies unless a native capability is genuinely missing.

All contributions are under the repository's MIT license. Third-party code/assets need their original attribution and license review. Do not copy proprietary product code, branding, or assets.

For redaction/security changes, use synthetic adversarial fixtures and independent extraction checks. Do not claim secure content removal based on appearance alone.
