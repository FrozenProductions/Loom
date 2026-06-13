#!/bin/bash
set -e

APP="Loom"
DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCE_DIR="$DIR/Resources"
DIST_DIR="$DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP.app"

echo "==> Cleaning old build..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> Compiling..."
swift build -c release --product "$APP"

BINARY="$DIR/.build/release/$APP"
if [ ! -f "$BINARY" ]; then
  echo "Error: Binary not found at $BINARY"
  exit 1
fi

echo "==> Copying binary..."
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP"

echo "==> Copying Info.plist..."
cp "$RESOURCE_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Writing PkgInfo..."
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

echo "==> Copying app icon..."
cp "$RESOURCE_DIR/$APP.icns" "$APP_BUNDLE/Contents/Resources/$APP.icns"

echo "==> Copying resource bundle..."
for arch_dir in "$DIR/.build/arm64-apple-macosx/release" "$DIR/.build/x86_64-apple-macosx/release"; do
  RB="$arch_dir/${APP}_${APP}.bundle"
  if [ -d "$RB" ]; then
    cp -R "$RB" "$APP_BUNDLE/Contents/Resources/"
    break
  fi
done

echo "==> Ad-hoc signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Registering with Launch Services..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$APP_BUNDLE"
fi

echo "==> Refreshing Finder icon cache..."
touch "$APP_BUNDLE"

echo "==> ✅ Built $APP.app"
echo "==> Opening..."
open "$APP_BUNDLE"
