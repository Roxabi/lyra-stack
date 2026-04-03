#!/usr/bin/env bash
# Wrapper for forge server — serves $FORGE_DIR (default: ~/.roxabi/forge) on port 8080.
export FORGE_DIR="${FORGE_DIR:-${DIAGRAMS_DIR:-$HOME/.roxabi/forge}}"

# Use canonical serve.py installed by forge-init; fall back to local copy
CANONICAL="$HOME/.roxabi/forge/serve.py"
LOCAL="$(dirname "$0")/../serve.py"

if [ -f "$CANONICAL" ]; then
    exec python3 "$CANONICAL"
else
    exec python3 "$LOCAL"
fi
