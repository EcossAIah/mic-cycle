#!/bin/zsh
# Builds the app and packages it as build/mic-cycle-<version>.zip for a GitHub release.
set -eu
PROJECT_DIR="${0:A:h}"
APP_DIR="$PROJECT_DIR/build/Mic Cycle.app"
"$PROJECT_DIR/build-app.sh"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ZIP="$PROJECT_DIR/build/mic-cycle-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$APP_DIR" "$ZIP"
cd "$PROJECT_DIR/build"
shasum -a 256 "${ZIP:t}"
