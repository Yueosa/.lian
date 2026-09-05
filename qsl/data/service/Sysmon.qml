pragma Singleton

// ============================================================
// 系统监控 — Sysmon
// ============================================================
// 后端：sysmond → $XDG_RUNTIME_DIR/qsl/sysmon.json
// 进程：写 sysmon_cmd "process_list" → sysmon_process.json
// 档位：写 sysmon_cmd "detail 0|1" 切换 daemon 轮询频率（摘要档 GPU 15s，详情档 3s）
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
//   ensureDaemon() / refreshProcesses()
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
    // 栏上摘要：只看 snap JSON，不拉进程列表
    property bool summaryActive: false
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

    // PSI：过去 10 秒被「卡住」的时间占比，0–100。
    // 比 loadavg 直观得多——不必除以核心数，也分得清是谁在卡。
    property bool psiAvailable: false
    property real psiCpu: 0
    property real psiIo: 0
    property real psiMem: 0
    // full = 所有任务都被阻塞。CPU 无此概念（内核恒报 0），故只留 io / mem。
    property real psiIoFull: 0
    property real psiMemFull: 0
    property real diskPercent: 0
    property real diskUsedGB: 0
    property real diskTotalGB: 0
    property real uptimeSecs: 0

    readonly property string uptimeText: formatUptime(uptimeSecs)

    // ---- 基础信息：主机名与开机时长 ----
    // 这两个不走 sysmond。Overview 只想在身份行末尾显示一句「up 3d 5h」，为此把
    // 守护进程拉起来不划算——它一起来就持续采 CPU/GPU/网络，GPU 那档每次还 fork
    // 一个 nvidia-smi。而这两个值一个几乎不变、一个单调递增，读一次就够。
    //
    // 第 9 轮从 ui/island/OverviewPage.qml 搬来的：那里自己起了个 Process 读
    // /etc/hostname 和 /proc/uptime，还抄了一份逐字相同的 formatUptime。
    property string hostname: ""

    function refreshBasics() {
        basicsProc.running = true
    }

    Process {
        id: basicsProc
        command: [
            "sh", "-c",
            "printf '%s\\n' \"$(cat /etc/hostname 2>/dev/null)\" "
            + "\"$(cut -d. -f1 /proc/uptime 2>/dev/null)\""
        ]
        stdout: StdioCollector {
            id: basicsOut
            onStreamFinished: {
                const lines = String(basicsOut.text || "").trim().split("\n")
                if (lines.length >= 1 && lines[0].trim().length)
                    root.hostname = lines[0].trim()
                // daemon 在跑的话它给的更新，别用一次性读的值盖掉
                if (lines.length >= 2 && !root.snapWatching) {
                    const secs = Number(lines[1].trim())
                    if (secs > 0)
                        root.uptimeSecs = secs
                }
            }
        }
    }

    // 原始列表；筛选/排序留给 UI，避免服务层绑死视图状态
    property var processes: []

    // ---- 迷你曲线用的历史 ----
    // 定长环形，满了从头丢，不会随运行时间增长。
    // 60 个采样点：摘要档 3s/次约 3 分钟，详情档 1s/次约 1 分钟。
    readonly property int historyLen: 60
    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []
    property var netDownHistory: []
    property var netUpHistory: []
    // PSI 平时恒为 0，只有卡顿瞬间才跳一下——不留历史等于什么都看不到
    property var psiCpuHistory: []
    property var psiIoHistory: []
    property var psiMemHistory: []

    function _peakOf(arr) {
        let m = 0
        for (let i = 0; i < arr.length; i++)
            if (arr[i] > m) m = arr[i]
        return m
    }
    readonly property real psiCpuPeak: _peakOf(psiCpuHistory)
    readonly property real psiIoPeak: _peakOf(psiIoHistory)
    readonly property real psiMemPeak: _peakOf(psiMemHistory)
    // 网速纵轴按近期峰值自适应，这里顺带算出来供 UI 直接用
    readonly property real netPeak: {
        let m = 0
        const a = root.netDownHistory
        const b = root.netUpHistory
        for (let i = 0; i < a.length; i++)
            if (a[i] > m) m = a[i]
        for (let i = 0; i < b.length; i++)
            if (b[i] > m) m = b[i]
        return m
    }

    property real _lastHistoryMs: 0

    function _push(arr, v) {
        // 超长时从头切一位，等价环形但省一个游标；60 元素的拷贝可忽略
        const next = arr.length >= root.historyLen ? arr.slice(1) : arr.slice(0)
        next.push(Number(v) || 0)
        return next
    }

    // FileView 偶尔会对一次写入触发两次 loaded，重复点会让曲线出现假台阶
    function _recordHistory() {
        const now = Date.now()
        if (now - root._lastHistoryMs < 500)
            return
        root._lastHistoryMs = now
        cpuHistory = _push(cpuHistory, root.cpuPercent)
        memHistory = _push(memHistory, root.ramPercent)
        gpuHistory = _push(gpuHistory, root.gpuPercent)
        netDownHistory = _push(netDownHistory, root.netDownBps)
        netUpHistory = _push(netUpHistory, root.netUpBps)
        psiCpuHistory = _push(psiCpuHistory, root.psiCpu)
        psiIoHistory = _push(psiIoHistory, root.psiIo)
        psiMemHistory = _push(psiMemHistory, root.psiMem)
    }

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
            if (!summaryActive)
                ready = false
        }
    }

    function setSummaryActive(active) {
        summaryActive = !!active
        if (summaryActive) {
            ensureDaemon()
            snapReloadDelay.start()
        } else if (!detailActive) {
            ready = false
        }
    }

    readonly property bool snapWatching: detailActive || summaryActive

    function ensureDaemon() {
        ensureProc.running = true
    }

    function refreshProcesses() {
        if (!detailActive)
            return
        cmdProc.running = true
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
        psiAvailable = !!ld.psi_available
        psiCpu = Number(ld.psi_cpu) || 0
        psiIo = Number(ld.psi_io) || 0
        psiMem = Number(ld.psi_mem) || 0
        psiIoFull = Number(ld.psi_io_full) || 0
        psiMemFull = Number(ld.psi_mem_full) || 0
        const disk = data.disk || {}
        diskPercent = Number(disk.percent) || 0
        diskUsedGB = Number(disk.used_gb) || 0
        diskTotalGB = Number(disk.total_gb) || 0
        uptimeSecs = Number(data.uptime_secs) || 0
        ready = true
        daemonOk = true
        _recordHistory()
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
        path: root.snapWatching ? root.snapPath : ""
        watchChanges: root.snapWatching
        onLoaded: {
            if (root.snapWatching)
                root.applySnapText(text())
        }
        onFileChanged: {
            if (root.snapWatching)
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

    // 告诉 daemon 该用哪一档轮询：只有顶栏摘要在看时不必 1s 采一次，
    // GPU 更不必——它每采一次就 fork 一个 nvidia-smi。
    Process {
        id: tierProc
        property string mode: "0"
        // 追加而非截断：与 process_list 共用同一个命令文件，截断会互相覆盖
        command: [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\" && printf 'detail "
            + tierProc.mode + "\\n' >> \"$XDG_RUNTIME_DIR/qsl/sysmon_cmd\""
        ]
    }

    function _syncDaemonTier() {
        const want = root.detailActive ? "1" : "0"
        if (tierProc.mode === want && tierProc.running)
            return
        tierProc.mode = want
        tierProc.running = true
    }

    onDetailActiveChanged: _syncDaemonTier()

    // 开页 / 每 2s：写命令 → 稍后再读进程 JSON（等 daemon 轮询）
    Process {
        id: cmdProc
        command: [
            "bash", "-lc",
            "mkdir -p \"$XDG_RUNTIME_DIR/qsl\" && printf 'process_list\\n' >> \"$XDG_RUNTIME_DIR/qsl/sysmon_cmd\""
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
            // daemon 可能是刚被拉起来的，默认在摘要档；补一次当前档位
            root._syncDaemonTier()
            if (root.snapWatching) {
                snapReloadDelay.start()
            }
        }
    }

    Timer {
        id: snapReloadDelay
        interval: 350
        repeat: false
        onTriggered: {
            if (root.snapWatching)
                snapView.reload()
        }
    }
}
