// shell.qml — qsl 入口（当前只挂 App FreeWindow）
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui.freewindow.app

ShellRoot {
    AppWindow {
        id: appWindow
    }

    IpcHandler {
        target: "free-window-app"
        function toggle() { appWindow.toggle() }
        function open() { appWindow.openWindow() }
        function close() { appWindow.closeWindow() }
    }
}
