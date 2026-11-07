#!/bin/bash
set -euo pipefail
PLIST="$HOME/Library/LaunchAgents/id.telkom.jarvis.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "/Applications/JARVIS.app"
echo "JARVIS.app removed."
echo "User data remains in ~/Library/Application Support/JARVIS."
echo "Remove Keychain secret if desired:"
echo "security delete-generic-password -s id.telkom.jarvis -a gemini_api_key"
