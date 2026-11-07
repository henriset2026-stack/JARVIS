"""Native macOS menu-bar integration using PyQt6."""
from PyQt6.QtGui import QAction
from PyQt6.QtWidgets import QMenu, QSystemTrayIcon

class JarvisTray:
    def __init__(self, ui):
        self.ui = ui
        self.tray = QSystemTrayIcon(ui._app)
        self.tray.setToolTip("JARVIS — Personal AI Assistant")
        icon = ui._win.windowIcon()
        if not icon.isNull():
            self.tray.setIcon(icon)
        menu = QMenu()
        show = QAction("Show JARVIS", menu)
        show.triggered.connect(self.show)
        menu.addAction(show)
        hide = QAction("Hide JARVIS", menu)
        hide.triggered.connect(self.hide)
        menu.addAction(hide)
        menu.addSeparator()
        quit_action = QAction("Quit JARVIS", menu)
        quit_action.triggered.connect(self.quit)
        menu.addAction(quit_action)
        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._activated)
        self.tray.show()

    def _activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.show()

    def show(self):
        self.ui._win.showNormal()
        self.ui._win.raise_()
        self.ui._win.activateWindow()

    def hide(self):
        self.ui._win.hide()

    def quit(self):
        self.tray.hide()
        self.ui._app.quit()
