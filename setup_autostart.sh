#!/bin/bash
set -e

APP="$HOME/Applications/ProductivityTimer.app"

if [ ! -d "$APP" ]; then
    echo "⚠️  App nicht gefunden: $APP"
    echo "    Bitte zuerst ./build.sh ausführen."
    exit 1
fi

# Alten Eintrag entfernen, falls vorhanden
osascript -e 'tell application "System Events" to delete (every login item whose name is "ProductivityTimer")' 2>/dev/null || true

# Neu hinzufügen
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP\", hidden:false}"

echo "✓ Productivity Timer startet jetzt automatisch bei jedem Login."
echo ""
echo "  Zum Überprüfen: Systemeinstellungen → Allgemein → Anmeldeobjekte"
echo ""
echo "  Zum Deaktivieren:"
echo "  osascript -e 'tell application \"System Events\" to delete (every login item whose name is \"ProductivityTimer\")'"
