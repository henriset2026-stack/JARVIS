"""macOS Keychain helpers for JARVIS."""
from __future__ import annotations
import platform, subprocess
import sys
from pathlib import Path

if platform.system() == "Darwin" and getattr(sys, "frozen", False):
    _app_name = Path(sys.executable).resolve().parents[2].stem.lower()
else:
    _app_name = "jarvis"
SERVICE = f"id.telkom.{_app_name}"
ACCOUNT = "gemini_api_key"

def get_key() -> str | None:
    if platform.system() != "Darwin":
        return None
    try:
        p = subprocess.run(
            ["security", "find-generic-password", "-s", SERVICE, "-a", ACCOUNT, "-w"],
            capture_output=True, text=True, check=False,
        )
        return p.stdout.strip() or None
    except Exception:
        return None

def set_key(value: str) -> bool:
    if platform.system() != "Darwin" or not value:
        return False
    try:
        subprocess.run(
            ["security", "delete-generic-password", "-s", SERVICE, "-a", ACCOUNT],
            capture_output=True, text=True, check=False,
        )
        p = subprocess.run(
            ["security", "add-generic-password", "-U", "-s", SERVICE,
             "-a", ACCOUNT, "-w", value.strip()],
            capture_output=True, text=True, check=False,
        )
        return p.returncode == 0
    except Exception:
        return False
