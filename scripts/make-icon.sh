#!/bin/zsh
# Renders the app icon (concept A, "Faders") from App/Icon/IconRenderer.swift
# into App/AppIcon.icns. Re-run after changing the renderer.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT

# Compile once, then render each size natively (sharper than downscaling).
BIN=$(mktemp -d)/iconrenderer
swiftc -O App/Icon/IconRenderer.swift -o "$BIN" 2>&1 | grep -v warning || true

for size in 16 32 128 256 512; do
    "$BIN" a "$ICONSET/icon_${size}x${size}.png" $size
    "$BIN" a "$ICONSET/icon_${size}x${size}@2x.png" $((size * 2))
done
iconutil -c icns "$ICONSET" -o App/AppIcon.icns
rm -f "$BIN"
echo "✓ Wrote App/AppIcon.icns"
