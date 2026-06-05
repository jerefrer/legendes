#!/bin/bash
# Build "Légendes.app" — a double-clickable macOS app bundle around the SwiftPM
# executable. The bundle's CFBundleName/CFBundleDisplayName make "Légendes"
# appear in the menu bar and the Dock (the Swift module names stay unchanged).
set -euo pipefail

APP_NAME="Légendes"
BUNDLE_ID="com.legendes.Legendes"
EXECUTABLE_PRODUCT="VideoTagging"   # SwiftPM product name (internal)
# Version comes from the release tag in CI (LEGENDES_VERSION=v1.2.3); default for local builds.
VERSION="${LEGENDES_VERSION:-1.0}"
VERSION="${VERSION#v}"

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"

echo "Building release binary…"
swift build -c release --product "$EXECUTABLE_PRODUCT"

BIN_PATH="$(swift build -c release --product "$EXECUTABLE_PRODUCT" --show-bin-path)"
APP="$ROOT/$APP_NAME.app"

echo "Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH/$EXECUTABLE_PRODUCT" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

# Copy any SwiftPM resource bundles next to the binary (none today, future-proof).
for b in "$BIN_PATH"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/" || true
done

# App icon (pre-generated .icns committed at app/AppIcon.icns).
if [ -f "$ROOT/app/AppIcon.icns" ]; then
  cp "$ROOT/app/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.video</string>
</dict>
</plist>
PLIST

# Ad-hoc code signature so macOS treats it as a stable app identity locally.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Done: $APP"
echo "Open it with:  open \"$APP\"    (or double-click it in Finder)"
