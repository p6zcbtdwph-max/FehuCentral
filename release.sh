#!/bin/bash
# Usage:
#   ./release.sh          — Release mit aktueller VERSION
#   ./release.sh patch    — Bump 2.0.0 → 2.0.1, dann Release
#   ./release.sh minor    — Bump 2.0.0 → 2.1.0, dann Release
#   ./release.sh major    — Bump 2.0.0 → 3.0.0, dann Release
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

bump_version() {
    local v=$1 part=$2
    IFS='.' read -r major minor patch <<< "$v"
    case $part in
        major) echo "$((major+1)).0.0" ;;
        minor) echo "$major.$((minor+1)).0" ;;
        patch) echo "$major.$minor.$((patch+1))" ;;
        *)     echo "$v" ;;
    esac
}

# Version bestimmen
CURRENT=$(tr -d '[:space:]' < VERSION)
if [[ "$1" == "patch" || "$1" == "minor" || "$1" == "major" ]]; then
    NEW_VERSION=$(bump_version "$CURRENT" "$1")
    echo "$NEW_VERSION" > VERSION
    echo "→ Version: $CURRENT → $NEW_VERSION"
else
    NEW_VERSION=$CURRENT
    echo "→ Version: $NEW_VERSION"
fi

# Sicherstellen, dass kein Tag gleichen Namens existiert
TAG="v$NEW_VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "✗ Tag $TAG existiert bereits. Bump die Version oder lösch den Tag zuerst."
    exit 1
fi

# Build
./build.sh

# App zippen
APP="$HOME/Applications/FehuCentral.app"
ZIP="/tmp/FehuCentral-$TAG.zip"
echo "→ Erstelle $ZIP..."
ditto -c -k --sequesterRsrc "$APP" "$ZIP"

# Commit + Tag
git add VERSION
git diff --cached --quiet || git commit -m "chore: Release $TAG

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
git tag -a "$TAG" -m "Release $TAG"
git push
git push origin "$TAG"

# GitHub Release
echo "→ Erstelle GitHub Release $TAG..."
gh release create "$TAG" "$ZIP" \
    --title "Fehu Central $TAG" \
    --generate-notes \
    --latest

echo "✓ Release $TAG veröffentlicht!"
echo "  https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/$TAG"
