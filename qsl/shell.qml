// shell.qml — qsl 入口
//
// 可编辑的本地数据文件（原设置面板「文件」页，页面已删）：
//   asset/hotkeys.json              快捷键 + IPC 速查，左栏 keys 页读它
//   asset/calendar/<年>.json        法定节假日 / 调休 / 节日，Calendar 单例读它
//   ~/.local/share/qsl/todo.json    待办，左栏 todo 页读写
//   ui/lock/pam/password.conf       锁屏 PAM 配置
// 改完 hotkeys / calendar 需重启 qs 才生效（FileView 只在启动时读一次）。
//
// IPC 目录见左栏 keys 页的 IPC 组；运行时真实注册表用 `qs ipc show`。
//
//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import qs.data.state
import qs.data.service
import qs.ui.frame
import qs.ui.freewindow.app
import qs.ui.freewindow.clipboard
import qs.ui.freewindow.websearch
import qs.ui.lock

ShellRoot {
    // 合并框窗：顶栏两段 + 三边 rail + 灵动岛 + 四撑位窗 + 四凹角耳（见 ui/frame/）
    Frame {}

    // App / Clipboard 常驻：IPC 现场 create 或 map layer 会卡一帧再播动画
    AppWindow {
        id: appWindow
    }

    ClipboardWindow {
        id: clipboardWindow
    }

    // ---- 冷路径懒加载：WebSearch（低频）----
    Component { id: webSearchComp; WebSearch {} }

    Loader { id: webSearchLoader; active: false; sourceComponent: webSearchComp }

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
        id: webSearchUnload
        interval: 480
        repeat: false
        onTriggered: maybeUnload(webSearchLoader)
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
    // C/V/N 三个面板与它们的 IPC（target sidebar / rightbar / notif）现在住在
    // 合并框窗里，见 ui/frame/FramePanels.qml——IpcHandler 的 target 全局唯一，
    // 只能挂在「只创建一次」的地方，而框窗本身是按屏派生的

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
        function toggle() { clipboardWindow.toggle() }
        function open() { clipboardWindow.openWindow() }
        function close() { clipboardWindow.closeWindow() }
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
