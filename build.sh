#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
app="$PWD/MechaPets.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# Native architecture; explicitly target macOS 13 rather than the build host OS.
arch_name="$(uname -m)"
module_cache="$(mktemp -d "${TMPDIR:-/tmp}/mechapets-swift.XXXXXX")"
trap 'rm -rf "$module_cache"' EXIT
xcrun swiftc -O -target "${arch_name}-apple-macosx13.0" -module-cache-path "$module_cache" Sources/Motion.swift Sources/Forge.swift Sources/Robot.swift Sources/Workload.swift Sources/WorkloadTests.swift Sources/Tests.swift Sources/main.swift -o "$app/Contents/MacOS/MechaPets" -framework AppKit -framework QuartzCore -lsqlite3
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MechaPets</string>
<key>CFBundleIdentifier</key><string>io.github.exorobotics.mechapets</string>
<key>CFBundleName</key><string>MechaPets</string>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundleShortVersionString</key><string>0.3.1</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$app"
"$app/Contents/MacOS/MechaPets" --self-test
