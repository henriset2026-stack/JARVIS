#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"
cd "$ROOT"

if [[ ! -x "$PYTHON" ]]; then
    echo "Python environment not found: $PYTHON" >&2
    exit 1
fi

echo "==> Building TANIA.app"
"$PYTHON" -m PyInstaller --noconfirm --clean macos/TANIA.spec

APP="$ROOT/dist/TANIA.app"
[[ -d "$APP" ]] || { echo "TANIA.app was not built." >&2; exit 1; }

PKGROOT="$ROOT/build/tania-pkgroot"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/Applications"
ditto "$APP" "$PKGROOT/Applications/TANIA.app"

echo "==> Creating macOS installer"
pkgbuild \
    --root "$PKGROOT" \
    --install-location / \
    --identifier id.telkom.tania.installer \
    --version 1.0.0 \
    "$ROOT/dist/TANIA-macOS.pkg"

DMGROOT="$ROOT/build/tania-dmg-root"
rm -rf "$DMGROOT"
mkdir -p "$DMGROOT"
ditto "$APP" "$DMGROOT/TANIA.app"
ln -s /Applications "$DMGROOT/Applications"
hdiutil create \
    -volname TANIA \
    -srcfolder "$DMGROOT" \
    -ov \
    -format UDZO \
    "$ROOT/dist/TANIA-macOS.dmg"

echo "Installers created:"
echo "  $ROOT/dist/TANIA-macOS.pkg"
echo "  $ROOT/dist/TANIA-macOS.dmg"
