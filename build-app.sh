#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Mic Cycle.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/module-cache"
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
# Universal binary (Apple silicon + Intel). -file-prefix-map keeps the checkout path out of the binary.
for ARCH in arm64 x86_64; do
  xcrun swiftc -parse-as-library -swift-version 5 -target "$ARCH-apple-macos13.0" -O \
    -file-prefix-map "$PROJECT_DIR=." \
    -module-cache-path "$BUILD_DIR/module-cache" \
    "$PROJECT_DIR"/App/*.swift -o "$BUILD_DIR/MicCycle-$ARCH" \
    -framework SwiftUI -framework AppKit -framework CoreAudio -framework Carbon -framework ServiceManagement
done
lipo -create "$BUILD_DIR/MicCycle-arm64" "$BUILD_DIR/MicCycle-x86_64" -output "$APP_DIR/Contents/MacOS/MicCycle"
rm "$BUILD_DIR/MicCycle-arm64" "$BUILD_DIR/MicCycle-x86_64"
strip -x "$APP_DIR/Contents/MacOS/MicCycle"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MicCycle</string>
  <key>CFBundleIdentifier</key><string>io.github.ecossaiah.mic-cycle</string>
  <key>CFBundleName</key><string>Mic Cycle</string>
  <key>CFBundleDisplayName</key><string>Mic Cycle</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleVersion</key><string>5</string>
  <key>CFBundleShortVersionString</key><string>1.4.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 Praneeth Bheema</string>
</dict></plist>
PLIST
# Ad-hoc signature by default. Set DEVELOPER_ID (e.g. "Developer ID Application: Name (TEAMID)")
# for a real signature with the hardened runtime, which notarization requires.
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP_DIR"
else
  codesign --force --sign - "$APP_DIR"
fi
print "Built $APP_DIR"
