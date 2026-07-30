pragma Singleton

// ============================================================
// 计时器 + 秒表服务 — Timers
// ============================================================
// 正计时（stopwatch）：从 0 开始，手动停止
// 倒计时（countdown）：设定秒数，时间到发 signal → 推灵动岛通知
// 持久化到 ~/.local/share/qsl/timer.json（防 qs 崩丢进度）
//
// 对外接口：
//   stopwatch            QtObject   正计时状态
//   countdown            QtObject   倒计时状态
//   startStopwatch()     开始/继续正计时
//   pauseStopwatch()     暂停正计时
//   resetStopwatch()     重置正计时
//   startCountdown(secs) 开始倒计时
//   pauseCountdown()     暂停倒计时
//   resetCountdown()     重置倒计时
//   signal countdownFinished()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal countdownFinished()

    // ---- 正计时 ----
    readonly property QtObject stopwatch: QtObject {
        property bool running: false
        property int elapsed: 0   // 累计毫秒
    }

    // ---- 倒计时 ----
    readonly property QtObject countdown: QtObject {
        property bool running: false
        property int total: 0      // 设定总秒数
        property int remaining: 0  // 剩余秒数
    }

    // ---- 正计时 API ----
    function startStopwatch() {
        stopwatch.running = true
        _tick.running = true
        _save()
    }

    function pauseStopwatch() {
        stopwatch.running = false
        if (!countdown.running)
            _tick.running = false
        _save()
    }

    function resetStopwatch() {
        stopwatch.running = false
        stopwatch.elapsed = 0
        if (!countdown.running)
            _tick.running = false
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
        _tick.running = true
        _save()
    }

    function pauseCountdown() {
        countdown.running = false
        if (!stopwatch.running)
            _tick.running = false
        _save()
    }

    function resetCountdown() {
        countdown.running = false
        countdown.remaining = 0
        countdown.total = 0
        if (!stopwatch.running)
            _tick.running = false
        _save()
    }

    // ---- 格式化辅助 ----
    function formatMs(ms) {
        const totalSec = Math.floor(ms / 1000)
        const h = Math.floor(totalSec / 3600)
        const m = Math.floor((totalSec % 3600) / 60)
        const s = totalSec % 60
        if (h > 0)
            return _pad(h) + ":" + _pad(m) + ":" + _pad(s)
        return _pad(m) + ":" + _pad(s)
    }

    function formatSec(sec) {
        const h = Math.floor(sec / 3600)
        const m = Math.floor((sec % 3600) / 60)
        const s = sec % 60
        if (h > 0)
            return _pad(h) + ":" + _pad(m) + ":" + _pad(s)
        return _pad(m) + ":" + _pad(s)
    }

    function _pad(n) { return n < 10 ? "0" + n : "" + n }

    // ---- Tick（100ms 精度） ----
    Timer {
        id: _tick
        interval: 100
        repeat: true
        running: false
        onTriggered: {
            if (stopwatch.running)
                stopwatch.elapsed += 100

            if (countdown.running) {
                // 每秒减一
                const now = Date.now()
                if (!root._lastCountdownTick || now - root._lastCountdownTick >= 1000) {
                    root._lastCountdownTick = now
                    countdown.remaining -= 1
                    if (countdown.remaining <= 0) {
                        countdown.remaining = 0
                        countdown.running = false
                        if (!stopwatch.running)
                            _tick.running = false
                        root.countdownFinished()
                        root._save()
                    }
                }
            }
        }
    }

    property real _lastCountdownTick: 0

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
