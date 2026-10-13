#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -m)" in
  arm64) ARCH=arm64; SHA=7ea647c7a7a9c1169be3f947000bc071ece2fade2cd6bd7e401e3675c6560cce ;;
  x86_64) ARCH=x64; SHA=d513a0530a0f0c1ca9929ded06660e27edb9a108a7d18d9df55a5fb060b091c8 ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
DEST="$ROOT/Vendor/pdfium"
RELEASE="chromium/8100-mac-$ARCH"
if [[ -f "$DEST/.release" && "$(cat "$DEST/.release")" == "$RELEASE" && -f "$DEST/lib/libpdfium.dylib" ]]; then exit 0; fi
mkdir -p "$ROOT/work/pdfium-download" "$ROOT/Vendor"
ARCHIVE="$ROOT/work/pdfium-download/pdfium-mac-$ARCH.tgz"
if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium/8100/pdfium-mac-$ARCH.tgz" --output "$ARCHIVE"
fi
printf '%s  %s\n' "$SHA" "$ARCHIVE" | shasum -a 256 --check
STAGE="$(mktemp -d "$ROOT/work/pdfium-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
tar -xzf "$ARCHIVE" -C "$STAGE"
install_name_tool -id @rpath/libpdfium.dylib "$STAGE/lib/libpdfium.dylib"
codesign --force --sign - "$STAGE/lib/libpdfium.dylib"
printf '%s' "$RELEASE" > "$STAGE/.release"
rm -rf "$DEST"
mv "$STAGE" "$DEST"
