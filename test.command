#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
testdir="$(mktemp -d)"
trap 'rm -rf "$testdir"' EXIT
xcrun swiftc -O -module-cache-path "$testdir/cache" Sources/Conversion.swift Sources/ImageFormat.swift Sources/ConversionOptions.swift Sources/QueueItem.swift Sources/AppModel.swift Tests/ConversionTests.swift -o "$testdir/tests"
"$testdir/tests"
/usr/bin/plutil -lint Info.plist "Convert Images.workflow/Contents/Info.plist" "Convert Images.workflow/Contents/document.wflow"
