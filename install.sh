#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/alvyn16/mercury.git"

echo "🪐 Installing Mercury AppImage Installer for Omarchy Linux..."

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin install "$REPO_URL" --enable
  echo "✅ Mercury installed successfully!"
else
  echo "Error: omarchy command not found. Please run this inside Omarchy Linux." >&2
  exit 1
fi
