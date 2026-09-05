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
import qs.ui.lock

ShellRoot {
    // 合并框窗：顶栏两段 + 三边 rail + 灵动岛 + C/V/N/A/Z/X/power 七面板 + 四撑位窗
    // + 四凹角耳（见 ui/frame/）。七个面板的 IPC 全在 FramePanels——IpcHandler
    // 的 target 全局唯一，只能挂在「只创建一次」的地方，而框窗本身按屏派生。
    //
    // 这里原先还养着一个 WebSearch 独立窗（Super+X 的搜索条）和一整套
    // free-window 的懒加载脚手架（ensureLoader / 480ms 卸载定时器 / Connections）。
    // 第 7 轮 X 改成磁贴面板，搜索条废掉，那套脚手架跟着整个拆了：框窗里的面板
    // 由 RailPage 自己管生命周期，不需要外部代持
    Frame {}

    Lock {
        id: lockScreen
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
