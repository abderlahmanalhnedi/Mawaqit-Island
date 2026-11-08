#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo "=== Mawaqit Island v0.4.1 — Community Edition ==="
bash scripts/build.sh
APP="$ROOT/build/Mawaqit Island.app"
DEST="$HOME/Applications"
mkdir -p "$DEST"
# Stop only the existing MawaqitIsland executable; no effect on SuperIsland.
/usr/bin/pkill -x MawaqitIsland >/dev/null 2>&1 || true
sleep 1
if [[ -d "$DEST/Mawaqit Island.app" ]]; then
  STAMP="$(date '+%Y%m%d-%H%M%S')"
  mv "$DEST/Mawaqit Island.app" "$DEST/Mawaqit Island.backup-$STAMP.app"
  echo "Backup: ~/Applications/Mawaqit Island.backup-$STAMP.app"
fi
cp -R "$APP" "$DEST/Mawaqit Island.app"
open "$DEST/Mawaqit Island.app"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Mawaqit Island.app/Contents/Info.plist" 2>/dev/null || true)"
echo "Installed Mawaqit Island version: ${VER:-unknown}"
echo "Installed! Look for the moon icon in the menu bar."
echo "First time? The mosque selection window opens automatically."
echo "Hover at the top center to open the island; move away to hide it."
