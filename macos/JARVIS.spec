from pathlib import Path
from PyInstaller.utils.hooks import collect_submodules

ROOT = Path(SPECPATH).resolve().parent

hiddenimports = (
    collect_submodules("google.genai")
    + collect_submodules("PyQt6")
    + collect_submodules("sounddevice")
    + collect_submodules("playwright")
)

datas = [
    (str(ROOT / "core"), "core"),
    (str(ROOT / "actions"), "actions"),
    (str(ROOT / "plugins"), "plugins"),
    (str(ROOT / "dashboard"), "dashboard"),
    (str(ROOT / "memory"), "memory"),
    (str(ROOT / "config"), "config"),
    (str(ROOT / "macos"), "macos"),
]

a = Analysis(
    [str(ROOT / "macos" / "macos_app.py")],
    pathex=[str(ROOT)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, [], exclude_binaries=True, name="JARVIS",
    debug=False, bootloader_ignore_signals=False, strip=False,
    upx=False, console=False,
)

app = BUNDLE(
    exe, a.binaries, a.datas,
    name="JARVIS.app",
    icon=str(ROOT / "macos" / "JARVIS.icns"),
    bundle_identifier="id.telkom.jarvis",
    version="1.0.0",
    info_plist={
        "CFBundleName": "JARVIS",
        "CFBundleDisplayName": "JARVIS",
        "CFBundleIdentifier": "id.telkom.jarvis",
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
        "NSPrincipalClass": "NSApplication",
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "12.0",
        "NSMicrophoneUsageDescription": "JARVIS uses the microphone for voice interaction.",
        "NSCameraUsageDescription": "JARVIS uses the camera when visual awareness is requested.",
        "NSAppleEventsUsageDescription": "JARVIS uses Apple Events for supported computer-control actions.",
    },
)
