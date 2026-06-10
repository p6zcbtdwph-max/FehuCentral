#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "→ Baue Productivity Timer..."
swift build -c release 2>&1

echo "→ Erstelle App-Bundle..."
APP="$HOME/Applications/ProductivityTimer.app"
CONTENTS="$APP/Contents"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

cp .build/release/KITimer "$CONTENTS/MacOS/KITimer"
chmod +x "$CONTENTS/MacOS/KITimer"

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>         <string>KITimer</string>
    <key>CFBundleIdentifier</key>         <string>de.ki.productivity-timer</string>
    <key>CFBundleName</key>               <string>Productivity Timer</string>
    <key>CFBundleDisplayName</key>        <string>Productivity Timer</string>
    <key>CFBundleVersion</key>            <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
</dict>
</plist>
EOF

# Laufende Instanz beenden
pkill -f "ProductivityTimer.app/Contents/MacOS/KITimer" 2>/dev/null || true
pkill -f "KITimer.app/Contents/MacOS/KITimer" 2>/dev/null || true

echo "→ Starte Productivity Timer..."
open "$APP"
echo "✓ Fertig! Productivity Timer läuft in der Menüleiste."
