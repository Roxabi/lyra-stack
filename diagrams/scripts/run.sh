#!/usr/bin/env bash
# Wrapper for diagrams server — serves $DIAGRAMS_DIR (default: ~/.roxabi/forge) on port 8080.
export DIAGRAMS_DIR="${DIAGRAMS_DIR:-$HOME/.roxabi/forge}"
exec python3 "$(dirname "$0")/../serve.py"
