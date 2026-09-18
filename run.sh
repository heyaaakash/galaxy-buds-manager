#!/bin/bash
# Incrementally rebuild and package before launching, so edited files never run stale binaries.
set -euo pipefail
cd "$(dirname "$0")"
CONFIGURATION=debug SKIP_DMG=1 ./build_app.sh
pkill -x GalaxyBudsManager 2>/dev/null || true
open ".build/Galaxy Buds2 Pro Manager.app"
