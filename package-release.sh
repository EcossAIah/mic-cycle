#!/bin/zsh
# Builds the app and packages it as build/mic-cycle-<version>.zip and .dmg for a GitHub release,
# then writes the DMG checksum into the Homebrew cask.
# Optional: set DEVELOPER_ID and NOTARY_PROFILE (a `xcrun notarytool store-credentials` profile)
# to sign and notarize the DMG.
set -eu
PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Mic Cycle.app"
"$PROJECT_DIR/build-app.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"

ZIP="$BUILD_DIR/mic-cycle-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ZIP"

# DMG with the app and an Applications shortcut to drag it onto.
DMG="$BUILD_DIR/mic-cycle-$VERSION.dmg"
STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto --norsrc --noextattr "$APP_DIR" "$STAGE/Mic Cycle.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Mic Cycle" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
rm -rf "$STAGE"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" \
  "$PROJECT_DIR/Casks/mic-cycle.rb"
cd "$BUILD_DIR"
shasum -a 256 "${ZIP:t}" "${DMG:t}"
