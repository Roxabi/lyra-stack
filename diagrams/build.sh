#!/usr/bin/env bash
# build.sh — assemble _dist/ for static deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DIAGRAMS_DIR="${DIAGRAMS_DIR:-$HOME/.agent}"
DIST="$DIAGRAMS_DIR/_dist"

echo "▸ Regenerating manifest.json…"
python3 "$SCRIPT_DIR/gen-manifest.py"

echo "▸ Generating image gallery manifests…"
python3 "$SCRIPT_DIR/gen-image-manifests.py"

echo "▸ Syncing to _dist/…"
rm -rf "$DIST"
rsync -a --delete \
  --exclude='_dist/' \
  --exclude='*.py' \
  --exclude='__pycache__/' \
  --exclude='.git/' \
  "$DIAGRAMS_DIR/" "$DIST/"

# Copy gallery UI from repo into _dist
cp "$SCRIPT_DIR/index.html" "$DIST/index.html"

FILE_COUNT=$(find "$DIST" -type f | wc -l)
SIZE=$(du -sh "$DIST" | cut -f1)
echo "▸ Build ready: $FILE_COUNT files, $SIZE → $DIST"
