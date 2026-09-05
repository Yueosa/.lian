// FramePanels — C / V / N / A / Z 五个进入模式面板，只在主屏那份框窗里实例化
//
// 为什么单独一个文件而不是直接写在 FrameWindow 里：框窗是按屏派生的
// （bar/rail/岛本来就该每块屏都有一份），而这几个面板是主屏单份——合并前它们
// 就没套 Variants。FrameWindow 用 Loader { active: isKeyOwner } 挂载本文件，
// 于是多屏下也只有一份。
//
// IPC 也放在这里，同一个理由：IpcHandler 的 target 是全局唯一的，写在按屏
// 派生的作用域里会重复注册。挂在只创建一次的 Loader 内容里才安全。
// （shell.qml 那边留了指路注释）
//
// 三项窗口级诉求向上归并给框窗：一个 surface 只有一个 layer / 一个焦点模式 /
// 一个 mask。这里做的只是「三个租户取或」，判断在各自的 RailPage 里。

import QtQuick
import Quickshell
import Quickshell.Io
import qs.data.service
import qs.ui.clipboard
import qs.ui.launcher
import qs.ui.leftbar
import qs.ui.notif
import qs.ui.rightbar

Item {
    id: root

    anchors.fill: parent

    readonly property bool wantsOverlay: leftbar.wantsOverlay
        || rightbar.wantsOverlay || notifCenter.wantsOverlay
        || launcher.wantsOverlay || clipboard.wantsOverlay
    readonly property bool wantsKeyboard: leftbar.wantsKeyboard
        || rightbar.wantsKeyboard || notifCenter.wantsKeyboard
        || launcher.wantsKeyboard || clipboard.wantsKeyboard

    // 框窗算 mask 用：开态是整条，关态 0×0
    readonly property Item leftbarHitBox: leftbar.hitBox
    readonly property Item rightbarHitBox: rightbar.hitBox
    readonly property Item notifHitBox: notifCenter.hitBox
    readonly property Item launcherHitBox: launcher.hitBox
    readonly property Item clipboardHitBox: clipboard.hitBox

    Leftbar {
        id: leftbar
    }

    Rightbar {
        id: rightbar
    }

    NotifCenter {
        id: notifCenter
    }

    Launcher {
        id: launcher
    }

    ClipHistory {
        id: clipboard
    }

    // ---- IPC ----

    // 手动重载。
    //
    // 热重载有个盲区：quickshell 的文件监视只认启动那一遍解析到的目录，而这几个
    // 面板全在框窗的 Loader { active: isKeyOwner } 里懒加载 —— ui/launcher、
    // ui/clipboard、ui/notif、data/launcher、data/clipboard 里的改动它一概收不到
    // （.js 文件不管在哪都不监视）。改完那些文件保存了却"什么都没变"，多半是这个，
    // 不是改错了。qs ipc call shell reload 手动叫一次即可
    IpcHandler {
        target: "shell"
        function reload() { Quickshell.reload(false) }
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
        target: "rightbar"
        function toggle() { rightbar.toggle() }
        function open(view: string) { rightbar.openView(view) }
        function next() { rightbar.next() }
        function prev() { rightbar.prev() }
        function close() { rightbar.closeWindow() }
    }

    // A 的 IPC 从 "free-window-app" 改名成 "launcher"：它已经不是自由窗了。
    // hypr/lua/binds.lua 的 Super+A 跟着改
    IpcHandler {
        target: "launcher"
        function toggle() { launcher.toggle() }
        function open() { launcher.openPage("apps") }
        function close() { launcher.closeWindow() }
    }

    // Z 的 IPC 从 "free-window-clipboard" 改名成 "clipboard"：它也不是自由窗了。
    // hypr/lua/binds.lua 的 Super+Z 跟着改
    IpcHandler {
        target: "clipboard"
        function toggle() { clipboard.toggle() }
        function open() { clipboard.openPage("clips") }
        function close() { clipboard.closeWindow() }
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
}
