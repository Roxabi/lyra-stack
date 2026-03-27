#!/usr/bin/env bash
# Wrapper for diagrams server — serves ~/.agent/ on port 8080.
export DIAGRAMS_DIR="$HOME/.agent"
exec python3 "$(dirname "$0")/../serve.py"
