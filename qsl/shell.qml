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
import qs.ui.freewindow.websearch
import qs.ui.lock
import qs.ui.settings

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

    WebSearch {
        id: webSearch
    }

    Lock {
        id: lockScreen
    }

    ControlCenter {
        id: controlCenter
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
        function dnd() {
            Notification.toggleDnd()
            return Notification.dndEnabled ? "DND_ON" : "DND_OFF"
        }
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
        target: "websearch"
        function toggle() { webSearch.toggle() }
        function open() { webSearch.openWindow() }
        function close() { webSearch.closeWindow() }
    }

    IpcHandler {
        target: "lock"
        function lock() { return lockScreen.lock() }
        function status() { return lockScreen.isLocked() ? "LOCKED" : "UNLOCKED" }
    }

    IpcHandler {
        target: "settings"
        function open() { controlCenter.openWindow() }
        function close() { controlCenter.closeWindow() }
        function toggle() { controlCenter.toggle() }
    }

    IpcHandler {
        target: "island"
        function hub() { return Island.hub() }
        function switcher() { return Island.switcher() }
        function wallpaper() { return Island.wallpaper() }
        function media() { return Island.media() }
        function weather() { return Island.weather() }
        function close() { Island.closeHub(); return "CLOSED" }
        function togglelayer() { return Island.toggleLayer() }

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
