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

    // App 常驻：左侧壁纸 OpacityMask 重载会闪；关态靠 FreeWindow.visible=contentActive 卸 layer
    AppWindow {
        id: appWindow
    }

    // ---- 冷路径懒加载：Settings / WebSearch / Clipboard（无重图预缓存需求）----
    Component { id: clipboardComp; ClipboardWindow {} }
    Component { id: webSearchComp; WebSearch {} }
    Component { id: settingsComp; ControlCenter {} }

    Loader { id: clipboardLoader; active: false; sourceComponent: clipboardComp }
    Loader { id: webSearchLoader; active: false; sourceComponent: webSearchComp }
    Loader { id: settingsLoader; active: false; sourceComponent: settingsComp }

    function ensureLoader(loader) {
        if (!loader.active)
            loader.active = true
        return loader.item
    }

    function scheduleUnload(loader, timer) {
        timer.restart()
    }

    function maybeUnload(loader) {
        const w = loader.item
        if (!w)
            return
        if (!w.open && !w.contentActive)
            loader.active = false
    }

    Timer {
        id: clipboardUnload
        interval: 480
        repeat: false
        onTriggered: maybeUnload(clipboardLoader)
    }
    Timer {
        id: webSearchUnload
        interval: 480
        repeat: false
        onTriggered: maybeUnload(webSearchLoader)
    }
    Timer {
        id: settingsUnload
        interval: 480
        repeat: false
        onTriggered: maybeUnload(settingsLoader)
    }

    Connections {
        target: clipboardLoader.item
        enabled: clipboardLoader.status === Loader.Ready
        function onOpenChanged() {
            if (clipboardLoader.item.open)
                clipboardUnload.stop()
            else
                scheduleUnload(clipboardLoader, clipboardUnload)
        }
    }
    Connections {
        target: webSearchLoader.item
        enabled: webSearchLoader.status === Loader.Ready
        function onOpenChanged() {
            if (webSearchLoader.item.open)
                webSearchUnload.stop()
            else
                scheduleUnload(webSearchLoader, webSearchUnload)
        }
    }
    Connections {
        target: settingsLoader.item
        enabled: settingsLoader.status === Loader.Ready
        function onOpenChanged() {
            if (settingsLoader.item.open)
                settingsUnload.stop()
            else
                scheduleUnload(settingsLoader, settingsUnload)
        }
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

    Lock {
        id: lockScreen
    }

    IpcHandler {
        target: "free-window-app"
        function toggle() { appWindow.toggle() }
        function open() { appWindow.openWindow() }
        function close() { appWindow.closeWindow() }
    }

    IpcHandler {
        target: "free-window-clipboard"
        function toggle() {
            const w = ensureLoader(clipboardLoader)
            if (w)
                w.toggle()
        }
        function open() {
            const w = ensureLoader(clipboardLoader)
            if (w)
                w.openWindow()
        }
        function close() {
            if (clipboardLoader.item)
                clipboardLoader.item.closeWindow()
        }
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
        function toggle() {
            const w = ensureLoader(webSearchLoader)
            if (w)
                w.toggle()
        }
        function open() {
            const w = ensureLoader(webSearchLoader)
            if (w)
                w.openWindow()
        }
        function close() {
            if (webSearchLoader.item)
                webSearchLoader.item.closeWindow()
        }
    }

    IpcHandler {
        target: "settings"
        function open(view: string) {
            const w = ensureLoader(settingsLoader)
            if (!w)
                return
            if (view && view.length > 0)
                w.openView(view)
            else
                w.openView("arch")
        }
        function close() {
            if (settingsLoader.item)
                settingsLoader.item.closeWindow()
        }
        function toggle() {
            const w = ensureLoader(settingsLoader)
            if (w)
                w.toggle()
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): string { return lockScreen.lock() }
        function status(): string { return lockScreen.isLocked() ? "LOCKED" : "UNLOCKED" }
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
