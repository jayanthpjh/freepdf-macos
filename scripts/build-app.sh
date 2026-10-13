#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/work/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/work/module-cache"
mkdir -p "$ROOT/work" "$ROOT/outputs"
swift build --disable-sandbox --configuration release --scratch-path "$ROOT/work/build" --cache-path "$ROOT/work/cache"
BIN="$(swift build --disable-sandbox --configuration release --scratch-path "$ROOT/work/build" --cache-path "$ROOT/work/cache" --show-bin-path)"
APP="$ROOT/outputs/FreePDF.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/FreePDF" "$APP/Contents/MacOS/FreePDF"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
# Ad-hoc signing permits local execution; this is not Developer ID signing or notarization.
codesign --force --sign - "$APP"
ditto -c -k --keepParent "$APP" "$ROOT/outputs/FreePDF-macOS.zip"
echo "Built: $APP"
