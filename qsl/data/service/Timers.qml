pragma Singleton

// ============================================================
// 计时器 + 秒表服务 — Timers
// ============================================================
// 正计时（stopwatch）：从 0 开始，手动停止
// 倒计时（countdown）：设定秒数，时间到发 notify-send
// 持久化到 ~/.local/share/qsl/timer.json
//
// 性能：
//   - Timer 1s interval（不是 100ms），只在运行时 active
//   - 属性变更仅秒级，不触发高频重绘
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal countdownFinished()

    // ---- 正计时（秒级） ----
    readonly property QtObject stopwatch: QtObject {
        property bool running: false
        property int elapsed: 0   // 累计秒数
    }

    // ---- 倒计时 ----
    readonly property QtObject countdown: QtObject {
        property bool running: false
        property int total: 0
        property int remaining: 0
    }

    // ---- 正计时 API ----
    function startStopwatch() {
        stopwatch.running = true
        _ensureTick()
        _save()
    }

    function pauseStopwatch() {
        stopwatch.running = false
        _ensureTick()
        _save()
    }

    function resetStopwatch() {
        stopwatch.running = false
        stopwatch.elapsed = 0
        _ensureTick()
        _save()
    }

    // ---- 倒计时 API ----
    function startCountdown(secs) {
        if (secs > 0) {
            countdown.total = secs
            countdown.remaining = secs
        }
        if (countdown.remaining <= 0)
            return
        countdown.running = true
        _ensureTick()
        _save()
    }

    function pauseCountdown() {
        countdown.running = false
        _ensureTick()
        _save()
    }

    function resetCountdown() {
        countdown.running = false
        countdown.remaining = 0
        countdown.total = 0
        _ensureTick()
        _save()
    }

    // ---- 格式化 ----
    function formatSec(sec) {
        const s = Math.max(0, Math.floor(sec))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const r = s % 60
        if (h > 0)
            return _pad(h) + ":" + _pad(m) + ":" + _pad(r)
        return _pad(m) + ":" + _pad(r)
    }

    function _pad(n) { return n < 10 ? "0" + n : "" + n }

    // ---- Tick（1s，仅在有活动计时时运行）----
    function _ensureTick() {
        _tick.running = stopwatch.running || countdown.running
    }

    Timer {
        id: _tick
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (stopwatch.running)
                stopwatch.elapsed += 1

            if (countdown.running) {
                countdown.remaining -= 1
                if (countdown.remaining <= 0) {
                    countdown.remaining = 0
                    countdown.running = false
                    root._ensureTick()
                    root.countdownFinished()
                    _notifyProc.command = ["notify-send", "-a", "qsl-timer",
                        "倒计时结束", root.formatSec(countdown.total) + " 已到"]
                    _notifyProc.running = true
                    root._save()
                }
            }
        }
    }

    Process {
        id: _notifyProc
        running: false
    }

    // ---- 持久化 ----
    // 写盘走 Process（python3 write_text），照 Todo 的口径：FileView.setText
    // 不可靠（Todo 那边有注释），且整段字符串写进 FileView 会同步阻塞。
    // _suppressLoad 防写盘回读把内存态打回旧内容；_storeReady 等 mkdir 完才
    // 放行首笔写入，_dirty 接住启动期就发生的写（恢复 running 会触发 _save）
    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"
    property bool _storeReady: false
    property bool _dirty: false
    property bool _suppressLoad: false

    function _save() {
        if (!_storeReady) {
            _dirty = true
            return
        }
        const payload = JSON.stringify({
            sw: { running: stopwatch.running, elapsed: stopwatch.elapsed },
            cd: { running: countdown.running, total: countdown.total, remaining: countdown.remaining }
        })
        _suppressLoad = true
        writeFile.command = [
            "bash", "-c",
            "python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2]+chr(10))' \"$1\" \"$2\"",
            "_",
            root._dataDir + "/timer.json",
            payload
        ]
        writeFile.running = true
        _dirty = false
    }

    function _loadFromText(raw) {
        if (_suppressLoad)
            return
        if (!raw)
            return
        try {
            const d = JSON.parse(raw)
            if (d.sw) {
                stopwatch.elapsed = d.sw.elapsed || 0
                if (d.sw.running) startStopwatch()
            }
            if (d.cd) {
                countdown.total = d.cd.total || 0
                countdown.remaining = d.cd.remaining || 0
                if (d.cd.running && countdown.remaining > 0) startCountdown(0)
            }
        } catch(e) {
            console.warn("[Timers] parse failed:", e)
        }
    }

    Process {
        id: writeFile
        onExited: (code) => {
            if (code !== 0)
                console.warn("[Timers] write failed, code=", code)
            Qt.callLater(() => {
                root._suppressLoad = false
            })
        }
    }

    Process {
        id: _mkdirProc
        command: ["mkdir", "-p", root._dataDir]
        running: true
        onExited: {
            root._storeReady = true
            if (root._dirty)
                root._save()
            else
                _file.reload()
        }
    }

    FileView {
        id: _file
        path: root._dataDir + "/timer.json"
        preload: true
        // 不 watch：避免外部写盘回读把内存态打回旧内容
        watchChanges: false
        atomicWrites: true
        onLoaded: root._loadFromText(text())
    }
}
