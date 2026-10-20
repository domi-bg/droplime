#!/bin/sh
# Regenerates Resources/AppIcon.icns from Sources/Droplime/LimeIcon.swift.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
cp scripts/make-icon.swift "$tmp/main.swift"  # top-level code is only allowed in main.swift
swiftc "$tmp/main.swift" Sources/Droplime/LimeIcon.swift -o "$tmp/make-icon"
"$tmp/make-icon" "$tmp/AppIcon.iconset"
mkdir -p Resources
iconutil -c icns "$tmp/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$tmp/AppIcon.iconset/icon_512x512@2x.png" Resources/AppIcon.png
rm -rf "$tmp"
echo "Created Resources/AppIcon.icns"
