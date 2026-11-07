#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON="${PYTHON:-python3}"

echo "==> Preparing Mark-LIII..."
"$PYTHON" macos/prepare_macos.py

echo "==> Installing dependencies..."
"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install -r requirements.txt
"$PYTHON" -m pip install --upgrade pyinstaller
"$PYTHON" -m playwright install chromium

echo "==> Building JARVIS.app..."
rm -rf build dist
"$PYTHON" -m PyInstaller --noconfirm --clean macos/JARVIS.spec

echo "==> Result: $(pwd)/dist/JARVIS.app"
