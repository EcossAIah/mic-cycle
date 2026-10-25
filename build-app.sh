#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Mic Cycle.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/module-cache"
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
ARCH="$(uname -m)"
# Release build. -file-prefix-map keeps the checkout path out of the binary.
xcrun swiftc -parse-as-library -swift-version 5 -target "$ARCH-apple-macos13.0" -O \
  -file-prefix-map "$PROJECT_DIR=." \
  -module-cache-path "$BUILD_DIR/module-cache" \
  "$PROJECT_DIR"/App/*.swift -o "$APP_DIR/Contents/MacOS/MicCycle" \
  -framework SwiftUI -framework AppKit -framework CoreAudio -framework Carbon
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
  <key>CFBundleVersion</key><string>4</string>
  <key>CFBundleShortVersionString</key><string>1.3.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 Praneeth Bheema</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP_DIR"
print "Built $APP_DIR"
