// shell.qml — qsl 入口（当前只挂 App FreeWindow）
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui.freewindow.app
import qs.ui.freewindow.clipboard

ShellRoot {
    AppWindow {
        id: appWindow
    }

    ClipboardWindow {
        id: clipboardWindow
    }

    IpcHandler {
        target: "free-window-app"
        function toggle() { appWindow.toggle() }
        function open() { appWindow.openWindow() }
        function close() { appWindow.closeWindow() }
    }

    IpcHandler {
        target: "free-window-clipboard"
        function toggle() { clipboardWindow.toggle() }
        function open() { clipboardWindow.openWindow() }
        function close() { clipboardWindow.closeWindow() }
    }
}
