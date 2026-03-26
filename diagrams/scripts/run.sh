#!/usr/bin/env bash
# Wrapper for diagrams server — serves ~/.agent/diagrams on port 8080.
cd "$HOME/.agent/diagrams"
exec python3 serve.py
