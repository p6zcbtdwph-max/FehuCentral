#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "→ Baue Fehu Central..."
swift build -c release 2>&1

echo "→ Erstelle App-Bundle..."
APP="$HOME/Applications/FehuCentral.app"
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
    <key>CFBundleIdentifier</key>         <string>de.fehu.central</string>
    <key>CFBundleName</key>               <string>Fehu Central</string>
    <key>CFBundleDisplayName</key>        <string>Fehu Central</string>
    <key>CFBundleVersion</key>            <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>NSPrincipalClass</key>           <string>NSApplication</string>
    <key>LSUIElement</key>                <true/>
    <key>NSHighResolutionCapable</key>    <true/>
    <key>NSCalendarsFullAccessUsageDescription</key> <string>Fehu Central zeigt deine heutigen Termine als Zeitblöcke an.</string>
</dict>
</plist>
EOF

# Laufende Instanz beenden
pkill -f "FehuCentral.app/Contents/MacOS/KITimer" 2>/dev/null || true
pkill -f "ProductivityTimer.app/Contents/MacOS/KITimer" 2>/dev/null || true
pkill -f "KITimer.app/Contents/MacOS/KITimer" 2>/dev/null || true

echo "→ Starte Fehu Central..."
open "$APP"
echo "✓ Fertig! Fehu Central läuft in der Menüleiste."
