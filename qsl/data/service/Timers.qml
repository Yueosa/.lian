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
    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"

    function _save() {
        const data = {
            sw: { running: stopwatch.running, elapsed: stopwatch.elapsed },
            cd: { running: countdown.running, total: countdown.total, remaining: countdown.remaining }
        }
        _file.setText(JSON.stringify(data))
    }

    function _load() {
        const raw = _file.text()
        if (!raw) return
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

    FileView {
        id: _file
        path: root._dataDir + "/timer.json"
        preload: true
        atomicWrites: true
        onLoaded: root._load()
    }
}
