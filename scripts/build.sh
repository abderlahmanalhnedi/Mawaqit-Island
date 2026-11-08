#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != "Darwin" ]]; then echo "macOS is required to build the AppKit interface." >&2; exit 1; fi
if ! xcrun --find swiftc >/dev/null 2>&1; then echo "Install Apple's Command Line Tools: xcode-select --install" >&2; exit 1; fi
APP="$ROOT/build/Mawaqit Island.app"
BIN="$APP/Contents/MacOS/MawaqitIsland"
mkdir -p "$(dirname "$BIN")" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SOURCES=(Sources/MawaqitCore.swift Sources/NotchGeometry.swift Sources/IslandModel.swift Sources/IslandViews.swift Sources/MawaqitIslandApp.swift)
FLAGS=(-swift-version 5 -O -parse-as-library -sdk "$SDK" -framework AppKit -framework SwiftUI -framework Combine -framework QuartzCore)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  mkdir -p build/arch
  for arch in x86_64 arm64; do
    echo "Compiling $arch..."
    xcrun swiftc "${FLAGS[@]}" -target "${arch}-apple-macos13.0" "${SOURCES[@]}" -o "build/arch/MawaqitIsland-$arch"
  done
  xcrun lipo -create build/arch/MawaqitIsland-x86_64 build/arch/MawaqitIsland-arm64 -output "$BIN"
else
  echo "Compiling for current Mac..."
  xcrun swiftc "${FLAGS[@]}" "${SOURCES[@]}" -o "$BIN"
fi
chmod +x "$BIN"
# Self-sign for local operation; this is NOT an Apple Developer ID signature or notarization.
/usr/bin/codesign --force --deep --sign - "$APP" >/dev/null
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
echo "Built: $APP"
