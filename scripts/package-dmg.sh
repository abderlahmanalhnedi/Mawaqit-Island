#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "DMG packaging requires macOS (hdiutil)." >&2
  exit 1
fi

APP="$ROOT/build/Mawaqit Island.app"
OUTPUT="$ROOT/build/Mawaqit-Island-macOS-universal.dmg"
if [[ ! -d "$APP" ]]; then
  echo "Application not found. First run UNIVERSAL=1 bash scripts/build.sh" >&2
  exit 1
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp/}mawaqit-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto "$APP" "$STAGING/Mawaqit Island.app"
/bin/ln -s /Applications "$STAGING/Applications"
/usr/bin/hdiutil create -volname "Mawaqit Island" -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT"

echo "Created: $OUTPUT"
echo "Contains Mawaqit Island.app and a drag-to-Applications shortcut."
echo "Warning: an ad-hoc signed DMG does NOT bypass macOS Gatekeeper."
