#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_SRC="$(pwd)/dist/JARVIS.app"
APP_DST="/Applications/JARVIS.app"
PLIST="$HOME/Library/LaunchAgents/id.telkom.jarvis.plist"

test -d "$APP_SRC" || { echo "Run macos/build_mac.sh first."; exit 1; }
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>id.telkom.jarvis</string>
<key>ProgramArguments</key><array><string>/Applications/JARVIS.app/Contents/MacOS/JARVIS</string></array>
<key>RunAtLoad</key><true/>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
EOF

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed /Applications/JARVIS.app and enabled launch-at-login."
