#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BUILD_DIR="$PROJECT_DIR/build/tests"
mkdir -p "$BUILD_DIR/module-cache"
xcrun swiftc -parse-as-library -module-cache-path "$BUILD_DIR/module-cache" \
  "$PROJECT_DIR/App/CoreAudioClient.swift" \
  "$PROJECT_DIR/Tests/CoreAudioLogicTests.swift" \
  -framework CoreAudio -o "$BUILD_DIR/core-audio-logic-tests"
"$BUILD_DIR/core-audio-logic-tests"
if [ "${1:-}" = "--logic-only" ]; then exit 0; fi
xcrun swiftc -parse-as-library -module-cache-path "$BUILD_DIR/module-cache" \
  "$PROJECT_DIR/App/CoreAudioClient.swift" \
  "$PROJECT_DIR/Tests/CoreAudioSmoke.swift" \
  -framework CoreAudio -o "$BUILD_DIR/core-audio-smoke"
"$BUILD_DIR/core-audio-smoke"
