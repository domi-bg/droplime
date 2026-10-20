#!/bin/sh
# Erzeugt die README-Bilder in docs/images neu.
set -e
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
cp scripts/make-screenshots.swift "$tmp/main.swift"  # Top-Level-Code geht nur in main.swift
swiftc "$tmp/main.swift" Sources/Droplime/WheelPanel.swift Sources/Droplime/WheelMode.swift \
    Sources/Droplime/Settings.swift Sources/Droplime/SettingsView.swift Sources/Droplime/Conversion/Converter.swift \
    Sources/Droplime/Actions/FileAction.swift Sources/Droplime/Actions/FloatPanel.swift -o "$tmp/make-screenshots"
"$tmp/make-screenshots" docs/images
sips -Z 512 Resources/AppIcon.png --out docs/images/icon.png >/dev/null
rm -rf "$tmp"
echo "docs/images aktualisiert"
