#!/bin/bash
set -euo pipefail

# AEON Voice — Build Script
# Compiles the SwiftUI app and creates a macOS .app bundle.
# Requires: macOS 13+, Xcode CommandLineTools (or Xcode)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/build/AEON Voice.app"
BINARY_NAME="AEONVoice"

cd "$PROJECT_DIR"

echo "Building $BINARY_NAME..."
swift build -c release

echo "Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp resources/Info.plist "$APP_BUNDLE/Contents/"

# Ad-hoc codesign so macOS doesn't flag it as damaged
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
touch "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
