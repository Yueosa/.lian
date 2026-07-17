// shell.qml — qsl 入口
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import qs.ui.freewindow.app
import qs.ui.freewindow.clipboard
import qs.ui.notif

ShellRoot {
    AppWindow {
        id: appWindow
    }

    ClipboardWindow {
        id: clipboardWindow
    }

    NotifCenter {
        id: notifCenter
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

    IpcHandler {
        target: "notif"
        function toggle() { notifCenter.toggle() }
        function open() { notifCenter.openWindow() }
        function close() { notifCenter.closeWindow() }
    }
}
