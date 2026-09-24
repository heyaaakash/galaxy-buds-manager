#!/bin/bash
# build_app.sh — Build Galaxy Buds2 Pro Manager .app bundle and .dmg
# Uses only swift CLI + macOS built-in tools (iconutil, hdiutil, sips).
set -euo pipefail

APP_NAME="Galaxy Buds2 Pro Manager"
EXEC_NAME="GalaxyBudsManager"
BUNDLE_ID="com.galaxybudsmanager.app"
VERSION="1.0.0"
CONFIGURATION="${CONFIGURATION:-release}"
SWIFT_ARGS=(--disable-sandbox --configuration "$CONFIGURATION")
if [ -n "${SWIFT_BUILD_PATH:-}" ]; then SWIFT_ARGS+=(--scratch-path "$SWIFT_BUILD_PATH"); fi
if [ -n "${SDKROOT:-}" ]; then SWIFT_ARGS+=(--sdk "$SDKROOT"); fi
if [ -n "${GBM_DEBUG_INFO_FORMAT:-}" ]; then SWIFT_ARGS+=(-debug-info-format "$GBM_DEBUG_INFO_FORMAT"); fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
BUILD_DIR="$SCRIPT_DIR/.build"
DIST_DIR="$SCRIPT_DIR/dist"
APP_OUTPUT_DIR="${APP_OUTPUT_DIR:-$DIST_DIR}"
APP_BUNDLE="$APP_OUTPUT_DIR/$APP_NAME.app"
DMG_FINAL="$DIST_DIR/GalaxyBuds2-Pro-Manager.dmg"
mkdir -p "$BUILD_DIR" "$APP_OUTPUT_DIR" "$DIST_DIR"

echo "═══════════════════════════════════════════════════════"
echo "  Galaxy Buds2 Pro Manager — Build Script"
echo "═══════════════════════════════════════════════════════"

# ── Step 1: Build release binary ────────────────────────────────
echo ""
echo "▶ Step 1: Building $CONFIGURATION binary..."
swift build "${SWIFT_ARGS[@]}"
BINARY_PATH="$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)/$EXEC_NAME"
if [ ! -x "$BINARY_PATH" ]; then
    echo "ERROR: The current build did not produce $BINARY_PATH"
    exit 1
fi
echo "   ✓ Binary: $BINARY_PATH ($(du -h "$BINARY_PATH" | cut -f1))"

# ── Step 2: Create .app bundle structure ───────────────────────
echo ""
echo "▶ Step 2: Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
echo "   ✓ Binary copied to bundle"

# ── Step 3: Generate .icns from app-icon.png ──────────────────
echo ""
echo "▶ Step 3: Generating app icon (.icns)..."

ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# macOS icon sizes needed for .iconset
# https://developer.apple.com/design/human-interface-guidelines/app-icons
ICON_SIZES=(16 32 128 256 512)
for SIZE in "${ICON_SIZES[@]}"; do
    # Standard resolution
    sips -z "$SIZE" "$SIZE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" "app-icon.png" >/dev/null 2>&1
    # Retina (@2x)
    DOUBLE=$((SIZE * 2))
    if [ "$DOUBLE" -le 1024 ]; then
        sips -z "$DOUBLE" "$DOUBLE" --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png" "app-icon.png" >/dev/null 2>&1
    fi
done
echo "   ✓ Generated ${#ICON_SIZES[@]} icon sizes"

iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
echo "   ✓ AppIcon.icns created"

# ── Step 4: Copy menubar icon into Resources ──────────────────
echo ""
echo "▶ Step 4: Copying menu bar icon..."
cp "menubar-icon.png" "$APP_BUNDLE/Contents/Resources/menubar-icon.png"
echo "   ✓ menubar-icon.png copied"

# ── Step 5: Copy Info.plist ────────────────────────────────────
echo ""
echo "▶ Step 5: Writing Info.plist..."
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo "   ✓ Info.plist written"

# ── Step 6: Create PkgInfo ────────────────────────────────────
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
echo "   ✓ PkgInfo written"

codesign --force --deep --sign - "$APP_BUNDLE"
if [ "${SKIP_DMG:-0}" = 1 ]; then
    rm -rf "$ICONSET_DIR"
    echo "Built: $APP_BUNDLE"
    exit 0
fi

# ── Step 6: Create DMG ────────────────────────────────────────
echo ""
echo "▶ Step 6: Creating DMG..."

DMG_TEMP="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_TEMP" "$DMG_FINAL"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create a symlink to /Applications for drag-to-install
ln -s /Applications "$DMG_TEMP/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_FINAL" 2>/dev/null

rm -rf "$DMG_TEMP"
echo "   ✓ DMG created: $DMG_FINAL ($(du -h "$DMG_FINAL" | cut -f1))"

# ── Step 7: Cleanup ───────────────────────────────────────────
echo ""
echo "▶ Step 7: Cleaning up temp iconset..."
rm -rf "$ICONSET_DIR"

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BUILD COMPLETE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  App Bundle: $APP_BUNDLE"
echo "  DMG:        $DMG_FINAL"
echo ""
echo "  To install:"
echo "    1. Open the DMG"
echo "    2. Drag 'Galaxy Buds2 Pro Manager' to Applications"
echo "    3. Grant Bluetooth permission on first launch"
echo "    4. Pair your Galaxy Buds2 Pro in System Settings > Bluetooth first"
echo ""
echo "  To run directly without installing:"
echo "    open \"$APP_BUNDLE\""
echo ""
