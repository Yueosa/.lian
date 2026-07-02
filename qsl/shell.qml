// shell.qml — qsl 入口（测试用）
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
    }
}
