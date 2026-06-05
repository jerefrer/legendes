#!/bin/bash
# Build "Légendes.app" — a double-clickable macOS app bundle around the SwiftPM
# executable. The bundle's CFBundleName/CFBundleDisplayName make "Légendes"
# appear in the menu bar and the Dock (the Swift module names stay unchanged).
set -euo pipefail

APP_NAME="Légendes"                 # .app folder + display name (menu bar / Dock)
EXE_NAME="Legendes"                 # ASCII Mach-O name; codesign mishandles an
                                    # accented main executable ("sealed resource
                                    # is missing or invalid"), so keep it ASCII.
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

cp "$BIN_PATH/$EXECUTABLE_PRODUCT" "$APP/Contents/MacOS/$EXE_NAME"
chmod +x "$APP/Contents/MacOS/$EXE_NAME"

# Embed Sparkle.framework (auto-update) and point the executable's rpath at it.
mkdir -p "$APP/Contents/Frameworks"
if [ -d "$BIN_PATH/Sparkle.framework" ]; then
  ditto "$BIN_PATH/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$EXE_NAME" 2>/dev/null || true
fi

# Copy any SwiftPM resource bundles next to the binary (none today, future-proof).
for b in "$BIN_PATH"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/" || true
done

# App icon (pre-generated .icns committed at app/AppIcon.icns).
if [ -f "$ROOT/app/AppIcon.icns" ]; then
  cp "$ROOT/app/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Sparkle auto-update feed (stable URL; the workflow publishes appcast.xml to the
# latest release). The public EdDSA key is injected from the environment so it
# isn't hardcoded; without it (local build) Sparkle simply can't verify updates.
SPARKLE_FEED="https://github.com/jerefrer/legendes/releases/latest/download/appcast.xml"
PUBKEY_PLIST=""
if [ -n "${SPARKLE_PUBLIC_KEY:-}" ]; then
  PUBKEY_PLIST="    <key>SUPublicEDKey</key>           <string>${SPARKLE_PUBLIC_KEY}</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>      <string>$EXE_NAME</string>
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
    <key>SUFeedURL</key>               <string>$SPARKLE_FEED</string>
    <key>SUEnableAutomaticChecks</key> <true/>
$PUBKEY_PLIST
</dict>
</plist>
PLIST

# Sign inside-out: Sparkle's nested helpers, then the framework, then the app.
# Developer ID + hardened runtime + timestamp for notarization when SIGN_IDENTITY
# is set; otherwise ad-hoc so local builds still run.
FW="$APP/Contents/Frameworks/Sparkle.framework"
if [ -n "${SIGN_IDENTITY:-}" ]; then
  if [ -d "$FW" ]; then
    V="$FW/Versions/B"
    for item in "$V/XPCServices/Downloader.xpc" "$V/XPCServices/Installer.xpc" "$V/Autoupdate" "$V/Updater.app"; do
      [ -e "$item" ] && codesign --force --options runtime --timestamp \
        --preserve-metadata=entitlements,identifier --sign "$SIGN_IDENTITY" "$item"
    done
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$FW"
  fi
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  [ -d "$FW" ] && codesign --force --deep --sign - "$FW" >/dev/null 2>&1 || true
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Done: $APP"
echo "Open it with:  open \"$APP\"    (or double-click it in Finder)"
