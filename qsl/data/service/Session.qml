pragma Singleton

// ============================================================
// 会话服务 — Session
// ============================================================
// 「让这台机器/这个会话/这个壳换个状态」的动作全在这儿：锁屏、注销、关机、
// 重启机器、重启壳自己。
//
// 第 9 轮从两处 UI 收上来的：
//   ui/power/PowerBar.qml     systemctl poweroff / reboot、hyprshutdown 探测
//   ui/island/OverviewPage.qml  自我重启的那一大段
// 它们是同一类事，散在两个不相干的面板里，各写各的。
//
// 这些动作都是**不可逆**的（重启壳算半个）。服务只负责「怎么做」，
// 「要不要做」的确认由 UI 管——PowerBar 的两段式上膛、Overview 的 3 秒自动
// 退回，都留在原地，因为那是交互设计不是系统调用。
// ============================================================

import QtQuick
import Quickshell
// 退出合成器要走 HyprService，见 logout() 里的说明
import qs.data.service

Singleton {
    id: root

    // ============================================================
    // 锁屏
    // ============================================================
    // 只发信号，不自己动手。锁屏实例（WlSessionLock）挂在 shell.qml 上，
    // 服务够不着它，也不该够得着——单例先于窗口存在。
    //
    // 原先 PowerBar 是这么干的：
    //     execDetached(["qs", "ipc", "call", "lock", "lock"])
    // 壳起一个进程，去调自己的 IPC，再绕回自己。一次 fork + 一次 socket 往返，
    // 只为把消息从面板送到同一进程里的另一个对象。
    signal lockRequested()

    function lock() {
        root.lockRequested()
    }

    // ============================================================
    // 结束会话 / 关机
    // ============================================================

    // 注销 = 退出合成器。优先用 hyprshutdown（如果装了），它会做收尾；
    // 没有就直接让合成器退出。
    //
    // 这里保持一整条 shell 回退链而不是在 QML 里分支：探测 hyprshutdown 在不在
    // 得起一个进程等它返回，而这条路径上多一次异步往返没有意义——注销本来就是
    // 「按下去就不回头」。合成器那半边的命令字串来自 HyprService，不在这儿硬写：
    // 「怎么跟 Hyprland 说话」只能有一个地方知道。
    function logout() {
        Quickshell.execDetached([
            "bash", "-lc",
            "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || "
            + HyprService.exitCommand
        ])
    }

    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"])
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"])
    }

    // ============================================================
    // 重启壳自己
    // ============================================================
    // 下面这段注释是踩出来的，别删。
    //
    // 杀自己按 **PID**，不按进程名。
    //
    // 原先写的是 `pkill -x qs`，赌的是「进程名一定叫 qs」。这个赌注输过一次：
    // 内核里的 comm 取的是 exec 时用的那个名字，我们全套配置起壳都用 qs
    // （autostart.lua、binds.lua、下面这条重启命令），所以平时确实叫 qs；但
    // /usr/bin/qs 是指向 quickshell 的符号链接，一旦有谁按**真实文件名**把它
    // 再 exec 一次（典型是走 /proc/self/exe 自我重启，argv 会变成不带参数的
    // /usr/bin/quickshell），这一份的 comm 就叫 quickshell 了。那时按钮点下去
    // 只白起一个新实例、老的还在，两份一起画。
    //
    // 所以不改成 `pkill -x quickshell`——那只是把赌注换个面押。也不能用
    // pkill -f 认命令行：下面这条 bash 的命令行里就带着进程名，会把自己一起
    // 杀掉（同类陷阱见 Cava.qml 里那个 [q] 写法）。PID 是自己的，谁也改不了。
    //
    // 先 TERM、轮询到死、超时再 KILL：直接接 sleep 0.5 是在赌它 500ms 内退得
    // 干净，退不干净就变成两份实例抢同一批 Wayland surface。
    function restartShell() {
        const wd = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        const xdg = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
        const dbus = Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""

        const pid = Quickshell.processId
        let cmd = "kill " + pid + "; "
            + "for i in $(seq 20); do kill -0 " + pid + " 2>/dev/null || break; sleep 0.1; done; "
            + "kill -9 " + pid + " 2>/dev/null; "
            + "export WAYLAND_DISPLAY=" + wd + "; "
            + "export XDG_RUNTIME_DIR=" + xdg + "; "
        if (dbus)
            cmd += "export DBUS_SESSION_BUS_ADDRESS='" + dbus + "'; "
        cmd += "MALLOC_CONF=background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000 "
            + "QSG_RENDER_LOOP=basic qs -d -n >/tmp/qsl_restart.log 2>&1 &"
        Quickshell.execDetached(["bash", "-lc", cmd])
    }
}
