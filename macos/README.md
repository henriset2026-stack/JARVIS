# JARVIS macOS packaging

Run on a MacBook from the Mark-LIII repository:

```bash
chmod +x macos/*.sh
./macos/build_mac.sh
open dist/JARVIS.app
```

Install to Applications and launch automatically at login:

```bash
./macos/install_mac.sh
```

Uninstall:

```bash
./macos/uninstall_mac.sh
```

The package adds:
- native PyInstaller `.app`
- native PyQt6 menu-bar icon
- LaunchAgent auto-start
- writable state under `~/Library/Application Support/JARVIS`
- Gemini key lookup/save via macOS Keychain, with JSON fallback
- microphone/camera/Apple Events usage descriptions
- GitHub Actions macOS arm64 build

The upstream Mark-LIII repository is CC BY-NC 4.0, so this packaging does not change its licensing terms.
