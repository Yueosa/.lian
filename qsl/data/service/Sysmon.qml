pragma Singleton

// ============================================================
// 系统监控 — Sysmon
// ============================================================
// 后端：sysmond → $XDG_RUNTIME_DIR/qsl/sysmon.json
// 进程：写 sysmon_cmd "process_list" → sysmon_process.json
// 仅 detailActive 时看文件 + 拉进程；关页停 Timer、清进程数组
// 电池不在此，用 Battery（UPower）
// ============================================================
// 对外接口：
//   detailActive / setDetailActive(bool)
//   ready / daemonOk
//   cpuPercent / cpuTemp
//   gpuAvailable / gpuPercent / gpuTemp
//   ramPercent / ramUsedGB / ramTotalGB / ramAppGB / ramCacheGB
//   swapUsedGB / swapTotalGB
//   netDownBps / netUpBps / netIface
//   load1 / load5 / load15
//   diskPercent / diskUsedGB / diskTotalGB
//   uptimeSecs / uptimeText
//   processes  // 原始 top50 数组（UI 侧筛选排序）
//   ensureDaemon() / refreshProcesses() / openHtop()
//   killProcess(pid, force)
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string runtimeDir: {
        const xdg = Quickshell.env("XDG_RUNTIME_DIR")
        return (xdg && xdg.length > 0) ? xdg : "/tmp"
    }
    readonly property string qslDir: runtimeDir + "/qsl"
    readonly property string snapPath: qslDir + "/sysmon.json"
    readonly property string procPath: qslDir + "/sysmon_process.json"
    readonly property string daemonBin: Quickshell.shellDir + "/backend/sysmon/build/sysmond"

    property bool detailActive: false
    property bool ready: false
    property bool daemonOk: false

    property real cpuPercent: 0
    property real cpuTemp: 0
    property bool gpuAvailable: false
    property real gpuPercent: 0
    property real gpuTemp: 0
    property real ramPercent: 0
    property real ramUsedGB: 0
    property real ramTotalGB: 0
    property real ramAppGB: 0
    property real ramCacheGB: 0
    property real swapUsedGB: 0
    property real swapTotalGB: 0
    property real netDownBps: 0
    property real netUpBps: 0
    property string netIface: ""
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property real diskPercent: 0
    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property real uptimeSecs: 0

    readonly property string uptimeText: formatUptime(uptimeSecs)

    // 原始列表；筛选/排序留给 UI，避免服务层绑死视图状态
    property var processes: []

    function setDetailActive(active) {
        detailActive = !!active
        if (detailActive) {
            ensureDaemon()
            snapView.reload()
            refreshProcesses()
            // 进程 CPU% 需两次采样；短间隔再拉一次
            procKick.start()
        } else {
            procTimer.stop()
            procKick.stop()
            processes = []
            ready = false
        }
    }

    function ensureDaemon() {
        ensureProc.running = true
    }

    function refreshProcesses() {
        if (!detailActive)
            return
        cmdProc.running = true
    }

    function openHtop() {
        Quickshell.execDetached(["kitty", "-e", "htop"])
    }

    function killProcess(pid, force) {
        const p = Number(pid)
        if (!(p > 0))
            return
        if (force)
            Quickshell.execDetached(["kill", "-9", String(p)])
        else
            Quickshell.execDetached(["kill", String(p)])
        // 稍后刷新列表
        Qt.callLater(() => {
            if (root.detailActive)
                root.refreshProcesses()
        })
    }

    function formatUptime(secs) {
        const s = Math.max(0, Math.floor(Number(secs) || 0))
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0)
            return d + "d " + h + "h"
        if (h > 0)
            return h + "h " + m + "m"
        return m + "m"
    }

    function formatBytes(bps) {
        const n = Math.max(0, Number(bps) || 0)
        if (n < 1024)
            return n.toFixed(0) + " B/s"
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + " K/s"
        if (n < 1024 * 1024 * 1024)
            return (n / (1024 * 1024)).toFixed(1) + " M/s"
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " G/s"
    }

    function formatMemKB(kb) {
        const n = Math.max(0, Number(kb) || 0)
        if (n < 1024)
            return n.toFixed(0) + " K"
        if (n < 1024 * 1024)
            return (n / 1024).toFixed(1) + " M"
        return (n / (1024 * 1024)).toFixed(2) + " G"
    }

    function applySnapshot(data) {
        if (!data || typeof data !== "object")
            return
        cpuPercent = Number(data.cpu_percent) || 0
        const th = data.thermal || {}
        cpuTemp = Number(th.cpu_package) || Number(th.cpu_hottest_core) || 0
        const g = data.gpu || {}
        gpuAvailable = !!g.available
        gpuPercent = Number(g.usage_percent) || 0
        gpuTemp = Number(g.temp) || 0
        const mem = data.memory || {}
        ramPercent = Number(mem.percent) || 0
        ramUsedGB = Number(mem.used_gb) || 0
        ramTotalGB = Number(mem.total_gb) || 0
        ramAppGB = Number(mem.app_gb) || 0
        ramCacheGB = Number(mem.cache_gb) || 0
        swapUsedGB = Number(mem.swap_used_gb) || 0
        swapTotalGB = Number(mem.swap_total_gb) || 0
        const net = data.network || {}
        netDownBps = Number(net.down_bps) || 0
        netUpBps = Number(net.up_bps) || 0
        netIface = net.iface ? String(net.iface) : ""
        const ld = data.load || {}
        load1 = Number(ld.load1) || 0
        load5 = Number(ld.load5) || 0
        load15 = Number(ld.load15) || 0
        const disk = data.disk || {}
        diskPercent = Number(disk.percent) || 0
        diskUsedGB = Number(disk.used_gb) || 0
        diskTotalGB = Number(disk.total_gb) || 0
        uptimeSecs = Number(data.uptime_secs) || 0
        ready = true
        daemonOk = true
    }

    function applyProcesses(data) {
        if (!detailActive)
            return
        if (!Array.isArray(data)) {
            processes = []
            return
        }
        // daemon 约定 top50；再兜底截断，避免异常大数组拖 UI
        processes = data.length > 50 ? data.slice(0, 50) : data
    }

    function applySnapText(raw) {
        try {
            const t = (raw || "").trim()
            if (!t)
                return
            applySnapshot(JSON.parse(t))
        } catch (e) {
            console.warn("Sysmon: snapshot parse failed", e)
        }
    }

    function applyProcText(raw) {
        try {
            const t = (raw || "").trim()
            if (!t)
                return
            applyProcesses(JSON.parse(t))
        } catch (e) {
            console.warn("Sysmon: process parse failed", e)
        }
    }

    FileView {
        id: snapView
        path: root.detailActive ? root.snapPath : ""
        watchChanges: root.detailActive
        onLoaded: {
            if (root.detailActive)
                root.applySnapText(text())
        }
        onFileChanged: {
            if (root.detailActive)
                reload()
        }
        onLoadFailed: {
            // daemon 尚未写出；ensure 后再试
        }
    }

    FileView {
        id: procView
        path: root.detailActive ? root.procPath : ""
        watchChanges: false
        onLoaded: {
            if (root.detailActive)
                root.applyProcText(text())
        }
        onLoadFailed: {
            // 首次 process_list 前文件可能不存在
        }
    }

    // 开页 / 每 2s：写命令 → 稍后再读进程 JSON（等 daemon ≤200ms 轮询）
    Process {
        id: cmdProc
        command: [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\" && printf 'process_list\\n' > \"$XDG_RUNTIME_DIR/qsl/sysmon_cmd\""
        ]
        onExited: procReadDelay.start()
    }

    Timer {
        id: procReadDelay
        interval: 280
        repeat: false
        onTriggered: {
            if (root.detailActive)
                procView.reload()
        }
    }

    Timer {
        id: procTimer
        interval: 2000
        repeat: true
        running: root.detailActive
        onTriggered: root.refreshProcesses()
    }

    Timer {
        id: procKick
        interval: 900
        repeat: false
        onTriggered: {
            if (root.detailActive)
                root.refreshProcesses()
        }
    }

    Process {
        id: ensureProc
        command: [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\"; "
            + "if pgrep -x sysmond >/dev/null; then exit 0; fi; "
            + "BIN=\"" + root.daemonBin + "\"; "
            + "if [ -x \"$BIN\" ]; then nohup \"$BIN\" >/dev/null 2>&1 & exit 0; fi; "
            + "exit 1"
        ]
        onExited: (code) => {
            root.daemonOk = (code === 0)
            if (root.detailActive) {
                snapReloadDelay.start()
            }
        }
    }

    Timer {
        id: snapReloadDelay
        interval: 350
        repeat: false
        onTriggered: {
            if (root.detailActive)
                snapView.reload()
        }
    }
}
