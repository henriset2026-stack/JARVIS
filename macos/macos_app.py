"""macOS launcher that adds a native menu-bar icon without changing main.py."""
from __future__ import annotations
import platform
import main as _main
from ui import JarvisUI as _JarvisUI

if platform.system() == "Darwin":
    from macos.macos_tray import JarvisTray
    class MacJarvisUI(_JarvisUI):
        def __init__(self, face_path: str, size=None):
            super().__init__(face_path, size)
            self._tray = JarvisTray(self)
else:
    MacJarvisUI = _JarvisUI

_main.JarvisUI = MacJarvisUI

if __name__ == "__main__":
    _main.main()
