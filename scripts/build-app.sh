#!/bin/sh
# Builds build/Droplime.app (release, with icon, no Dock icon) and signs it ad hoc.
# The version comes from $VERSION (default 0.1.0); the release workflow passes the tag.
set -e
cd "$(dirname "$0")/.."
VERSION="${VERSION:-0.1.0}"
swift build -c release
app=build/Droplime.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Droplime" "$app/Contents/MacOS/Droplime"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Droplime</string>
    <key>CFBundleDisplayName</key><string>Droplime</string>
    <key>CFBundleIdentifier</key><string>app.droplime.Droplime</string>
    <key>CFBundleExecutable</key><string>Droplime</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "Done: $app"
