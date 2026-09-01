#!/bin/bash
# run.sh — Build and launch Galaxy Buds2 Pro Manager as a proper .app
# Use this instead of 'swift run' — IOBluetooth RFCOMM requires an app bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Galaxy Buds2 Pro Manager"
APP_BUNDLE=".build/$APP_NAME.app"

# Kill any running instance
pkill -f GalaxyBudsManager 2>/dev/null || true
sleep 0.5

# Build the .app if it doesn't exist or if source is newer than binary
if [ ! -d "$APP_BUNDLE" ] || [ "Sources" -nt "$APP_BUNDLE/Contents/MacOS/GalaxyBudsManager" ] 2>/dev/null; then
    echo "Building..."
    ./build_app.sh 2>&1 | grep -E "✓|ERROR|BUILD"
fi

# Launch
echo "Launching $APP_NAME..."
open "$APP_BUNDLE"
echo "✓ App launched. Check your menu bar."
