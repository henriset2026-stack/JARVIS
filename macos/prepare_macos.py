"""Patch Mark-LIII persistence for a writable macOS user location + Keychain."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cfg = root / "memory" / "config_manager.py"
text = cfg.read_text(encoding="utf-8")

old = """def get_base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).resolve().parent.parent

BASE_DIR    = get_base_dir()
CONFIG_DIR  = BASE_DIR / "config"
CONFIG_FILE = CONFIG_DIR / "api_keys.json"
"""
new = """def get_base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).resolve().parent.parent

# Mutable per-user state must not be written into /Applications/JARVIS.app.
if sys.platform == "darwin":
    BASE_DIR = Path.home() / "Library" / "Application Support" / "JARVIS"
else:
    BASE_DIR = get_base_dir()

CONFIG_DIR  = BASE_DIR / "config"
CONFIG_FILE = CONFIG_DIR / "api_keys.json"
"""
if old in text:
    text = text.replace(old, new)

needle = "from pathlib import Path\n"
if "macos.macos_keychain" not in text:
    text = text.replace(
        needle,
        needle + "\ntry:\n    from macos.macos_keychain import get_key as _keychain_get, set_key as _keychain_set\nexcept Exception:\n    _keychain_get = _keychain_set = None\n"
    )

old2 = """def get_gemini_key() -> str | None:
    return load_api_keys().get("gemini_api_key")
"""
new2 = """def get_gemini_key() -> str | None:
    if sys.platform == "darwin" and _keychain_get:
        key = _keychain_get()
        if key:
            return key
    return load_api_keys().get("gemini_api_key")
"""
if old2 in text:
    text = text.replace(old2, new2)

old3 = """    data["gemini_api_key"] = gemini_api_key.strip()

    CONFIG_FILE.write_text(
        json.dumps(data, indent=2),
        encoding="utf-8"
    )
"""
new3 = """    value = gemini_api_key.strip()
    if sys.platform == "darwin" and _keychain_set and _keychain_set(value):
        data.pop("gemini_api_key", None)
        data["gemini_keychain"] = True
    else:
        data["gemini_api_key"] = value

    CONFIG_FILE.write_text(
        json.dumps(data, indent=2),
        encoding="utf-8"
    )
"""
if old3 in text:
    text = text.replace(old3, new3)

cfg.write_text(text, encoding="utf-8")
print("macOS preparation applied.")
