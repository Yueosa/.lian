// shell.qml — qsl 入口
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import qs.data.state
import qs.data.service
import qs.ui.bar
import qs.ui.freewindow.app
import qs.ui.freewindow.clipboard
import qs.ui.island
import qs.ui.leftbar
import qs.ui.notif
import qs.ui.rightbar

ShellRoot {
    Bar {}

    IslandShell {}

    AppWindow {
        id: appWindow
    }

    ClipboardWindow {
        id: clipboardWindow
    }

    NotifCenter {
        id: notifCenter
    }

    Leftbar {
        id: leftbar
    }

    Rightbar {
        id: rightbar
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

    IpcHandler {
        target: "rightbar"
        function toggle() { rightbar.toggle() }
        function open(view: string) { rightbar.openView(view) }
        function next() { rightbar.next() }
        function prev() { rightbar.prev() }
        function close() { rightbar.closeWindow() }
    }

    IpcHandler {
        target: "sidebar"
        function toggle() { leftbar.toggle() }
        function open(view: string) { leftbar.openView(view) }
        function next() { leftbar.next() }
        function prev() { leftbar.prev() }
        function close() { leftbar.closeWindow() }
    }

    IpcHandler {
        target: "island"
        function hub() { return Island.hub() }
        function switcher() { return Island.switcher() }
        function wallpaper() { return Island.wallpaper() }
        function media() { return Island.media() }
        function close() { Island.closeHub(); return "CLOSED" }

        function mediatoggle() {
            if (Media.active)
                Media.active.togglePlaying()
            return "OK"
        }
        function mediaprevious() {
            if (Media.active)
                Media.active.previous()
            return "OK"
        }
        function medianext() {
            if (Media.active)
                Media.active.next()
            return "OK"
        }
    }
}
