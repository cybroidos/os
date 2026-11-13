#!/usr/bin/env python3
"""CybroidOS Settings (cybroid-settings).

The window and every page are QML (qml/); this file is the thin layer under
them: it runs the system's own tools (nmcli, pactl, timedatectl, hostnamectl,
cybroid-appearance) without blocking the window, reads small files, and
follows the design in use (Horizon or Hex, Dark or Light) so the app changes
with the desktop.

    cybroid-settings [page]     page: wifi, sound, appearance, datetime, about
"""

import os
import sys

from PySide6.QtCore import (QFileSystemWatcher, QObject, QProcess, QTimer, Property, Signal, Slot)
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QJSValue, QQmlApplicationEngine, QmlElement, QmlSingleton
from PySide6.QtQuickControls2 import QQuickStyle

QML_IMPORT_NAME = "Cybroid.Settings"
QML_IMPORT_MAJOR_VERSION = 1

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")


def kde_scheme():
    """The colour scheme in kdeglobals ([General] ColorScheme)."""
    group = None
    try:
        with open(os.path.join(CONFIG, "kdeglobals"), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    group = line
                elif group == "[General]" and line.startswith("ColorScheme="):
                    return line.split("=", 1)[1]
    except OSError:
        pass
    return "CybroidHorizon"


@QmlElement
@QmlSingleton
class System(QObject):
    """Exposed to QML as the singleton System (import Cybroid.Settings)."""

    themeChanged = Signal()
    startPageChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._scheme = kde_scheme()
        self._start = START_PAGE
        self._procs = set()
        # kdeglobals is replaced, not written in place, so the folder is
        # watched; a short wait lets a theme change finish writing.
        self._watch = QFileSystemWatcher([CONFIG], self)
        self._later = QTimer(self, singleShot=True, interval=300)
        self._later.timeout.connect(self._reread)
        self._watch.directoryChanged.connect(lambda _p: self._later.start())

    def _reread(self):
        s = kde_scheme()
        if s != self._scheme:
            self._scheme = s
            self.themeChanged.emit()

    @Property(str, notify=themeChanged)
    def design(self):
        return "hex" if "Hex" in self._scheme else "horizon"

    @Property(bool, notify=themeChanged)
    def light(self):
        return self._scheme.endswith("Light")

    @Property(str, notify=startPageChanged)
    def startPage(self):
        return self._start

    def show_page(self, page):
        """Settings opened again (the dock, Control Centre): this window
        comes forward on that page."""
        self._start = page or self._start
        self.startPageChanged.emit()

    @Slot(list, QJSValue)
    def run(self, args, done):
        """Runs args (no shell) and calls done(output, exit code) when it ends."""
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)
        self._procs.add(p)

        def finished(code, _status):
            out = bytes(p.readAll()).decode("utf-8", "replace")
            self._procs.discard(p)
            p.deleteLater()
            if isinstance(done, QJSValue) and done.isCallable():
                done.call([out, code])

        def failed(_err):
            if p.state() == QProcess.NotRunning and p in self._procs:
                finished(127, None)

        p.finished.connect(finished)
        p.errorOccurred.connect(failed)
        p.start(str(args[0]), [str(a) for a in args[1:]])

    @Slot(list)
    def launch(self, args):
        """Starts an app on its own (KDE's settings pages, a terminal)."""
        QProcess.startDetached(str(args[0]), [str(a) for a in args[1:]])

    @Slot(str, result=str)
    def readText(self, path):
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                return f.read()
        except OSError:
            return ""

    @Slot(str, result=bool)
    def exists(self, path):
        return os.path.exists(path)


START_PAGE = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "wifi"


def main():
    # Our own controls are drawn in QML; the plain style keeps KDE's desktop
    # style from drawing under them.
    QQuickStyle.setStyle("Basic")
    app = QGuiApplication(sys.argv)
    # One Settings window: a second start hands its page to the first and ends.
    name = f"cybroid-settings-{os.getuid()}"
    other = QLocalSocket()
    other.connectToServer(name)
    if other.waitForConnected(300):
        other.write((sys.argv[1] if len(sys.argv) > 1 else "").encode() + b"\n")
        other.waitForBytesWritten(300)
        other.disconnectFromServer()
        return
    QLocalServer.removeServer(name)
    server = QLocalServer()
    server.listen(name)
    app.setApplicationName("cybroid-settings")
    app.setApplicationDisplayName("Settings")
    app.setDesktopFileName("cybroid-settings")
    app.setWindowIcon(QIcon.fromTheme("preferences-system"))
    engine = QQmlApplicationEngine()
    engine.addImportPath(os.path.join(HERE, "qml"))
    engine.load(os.path.join(HERE, "qml", "Main.qml"))
    if not engine.rootObjects():
        sys.exit(1)
    system = engine.singletonInstance("Cybroid.Settings", "System")

    def arrived():
        c = server.nextPendingConnection()
        if c is None:
            return

        def read():
            page = bytes(c.readAll()).decode(errors="replace").strip()
            system.show_page(page)
            c.disconnectFromServer()
        c.readyRead.connect(read)
    server.newConnection.connect(arrived)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
