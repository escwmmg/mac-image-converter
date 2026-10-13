#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p "Image Converter.app/Contents/MacOS"
mkdir -p "Image Converter.app/Contents/Resources"
builddir="$(mktemp -d)"
trap 'rm -rf "$builddir"' EXIT
xcrun swiftc -O -target arm64-apple-macosx13.0 -module-cache-path "$builddir/cache" Sources/*.swift -o "$builddir/ImageConverter"
cp "$builddir/ImageConverter" "Image Converter.app/Contents/MacOS/ImageConverter"
cp Info.plist "Image Converter.app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "Image Converter.app"
echo "Built Image Converter.app for Apple Silicon (macOS 13+)."
