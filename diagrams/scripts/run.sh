#!/usr/bin/env bash
# Wrapper for diagrams server — serves ~/.agent/ on port 8080.
cd "$HOME/.agent"
exec python3 serve.py
