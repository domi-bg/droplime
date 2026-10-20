#!/bin/sh
# Regenerates the README images in docs/images.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
cp scripts/make-screenshots.swift "$tmp/main.swift"  # top-level code is only allowed in main.swift
swiftc "$tmp/main.swift" Sources/Droplime/WheelPanel.swift Sources/Droplime/WheelMode.swift \
    Sources/Droplime/Settings.swift Sources/Droplime/SettingsView.swift Sources/Droplime/Localization.swift \
    Sources/Droplime/Conversion/Converter.swift \
    Sources/Droplime/Actions/FileAction.swift Sources/Droplime/Actions/FloatPanel.swift -o "$tmp/make-screenshots"
"$tmp/make-screenshots" docs/images
sips -Z 512 Resources/AppIcon.png --out docs/images/icon.png >/dev/null
rm -rf "$tmp"
echo "Updated docs/images"
