pragma Singleton

// ============================================================
// 提醒服务 — Reminder（qsl.md M2）
// ============================================================
// 三档：一次性 once（今天 HH:MM，过了滚到明天，响一次）/ 每天 daily /
// 指定日期 date（YYYY-MM-DD HH:MM，响一次）。
// 持久化 ~/.local/share/qsl/reminder.json（Process 写盘 + suppressLoad +
// mkdir 门，照 Todo 的口径——FileView.setText 那条路 Todo 已判不可靠）。
//
// 到点：发 reminderFired 信号 → Island 收进**常驻**提醒队列（一级岛提醒形态），
// 必须手动点掉。这条通路不经过 Notification，DnD 压不住它——提醒是用户自己
// 约的时间，不是外部应用的通知（qsl.md 明示 DnD 豁免）。
//
// qs 没跑就没有提醒：不常驻额外进程、不跨重启存活（qsl.md 定）。
// 恢复语义：daily 接着排、不补响错过的；once/date 已过点的直接丢弃。
//
// 性能：1s Timer 只在 items 非空时转（_ensureTick，有活动提醒才跑）；
// 每 tick 只做整数比大小，不做字符串拼接 / Date 分配——错过的代价是
// 响铃晚一秒，换整分钟的主线程安静。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal reminderFired(var payload)

    // { id, title, mode, at:"HH:MM", date:"YYYY-MM-DD"(date 档), atMs, dateMs, nextAt }
    property var items: []
    property int revision: 0
    property bool _storeReady: false
    property bool _dirty: false
    property bool _suppressLoad: false

    readonly property int count: {
        void revision
        return items.length
    }

    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"
    readonly property string filePath: _dataDir + "/reminder.json"

    function _bump() { revision++ }

    // ---- 时间解析（服务层只认这两种格式，UI 卡按同一套校验）----
    function _parseAt(s) {   // "HH:MM" → 当日毫秒偏移，失败 -1
        const m = /^(\d{1,2}):(\d{2})$/.exec(String(s || ""))
        if (!m)
            return -1
        const h = Number(m[1]), mi = Number(m[2])
        if (h > 23 || mi > 59)
            return -1
        return (h * 60 + mi) * 60000
    }

    function _parseDate(s) { // "YYYY-MM-DD" → 当天 0 点时间戳，失败 -1
        const m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(String(s || ""))
        if (!m)
            return -1
        const y = Number(m[1]), mo = Number(m[2]), d = Number(m[3])
        const t = new Date(y, mo - 1, d)
        if (t.getFullYear() !== y || t.getMonth() !== mo - 1 || t.getDate() !== d)
            return -1
        return t.getTime()
    }

    function _dayStart(ts) {
        const d = new Date(ts)
        d.setHours(0, 0, 0, 0)
        return d.getTime()
    }

    // now 之后的第一次到点。date 档钉死在给定日期；once/daily 先试今天、
    // 过了滚到明天（daily 每次响完再滚，见 _check）
    function _nextFire(atMs, mode, dateMs, now) {
        if (mode === "date")
            return dateMs + atMs
        let t = _dayStart(now) + atMs
        if (t <= now)
            t += 86400000
        return t
    }

    function add(title, mode, at, date) {
        const t = String(title || "").trim()
        const atMs = _parseAt(at)
        if (!t || atMs < 0)
            return { ok: false, error: "标题和时间（HH:MM）都要填" }
        const m = String(mode || "once")
        let dateMs = -1
        if (m === "date") {
            dateMs = _parseDate(date)
            if (dateMs < 0)
                return { ok: false, error: "日期要写 YYYY-MM-DD" }
        }
        const now = Date.now()
        const nextAt = _nextFire(atMs, m, dateMs, now)
        if (m === "date" && nextAt <= now)
            return { ok: false, error: "这个时间已经过了" }
        const item = {
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            title: t,
            mode: m,
            at: String(at),
            date: m === "date" ? String(date) : "",
            atMs: atMs,
            dateMs: dateMs,
            nextAt: nextAt
        }
        items = items.concat([item])
        _bump()
        _save()
        _ensureTick()
        return { ok: true, error: "" }
    }

    function remove(id) {
        items = items.filter(i => i && i.id !== id)
        _bump()
        _save()
        _ensureTick()
    }

    // 最近一次到点的时间戳（Overview 的提醒 MiniStat 用）。-1 = 没有
    readonly property int nextAt: {
        void revision
        let best = -1
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (it && it.nextAt > 0 && (best < 0 || it.nextAt < best))
                best = it.nextAt
        }
        return best
    }

    function hhmmOf(ts) {
        if (!(ts > 0))
            return "--:--"
        const d = new Date(ts)
        const p = n => (n < 10 ? "0" + n : "" + n)
        return p(d.getHours()) + ":" + p(d.getMinutes())
    }

    function _ensureTick() {
        tick.running = items.length > 0
    }

    // ---- tick（1s，仅 items 非空时运行）----
    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: false
        onTriggered: root._check(Date.now())
    }

    function _check(now) {
        if (items.length === 0)
            return
        const fired = []
        const next = []
        let changed = false
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (!it)
                continue
            if (it.nextAt > now) {
                next.push(it)
                continue
            }
            fired.push(it)
            changed = true
            if (it.mode === "daily") {
                // 响完滚到明天同一时刻；停机错过多天也只排最近的一次
                next.push(Object.assign({}, it,
                    { nextAt: _nextFire(it.atMs, "daily", -1, now) }))
            }
            // once / date：响一次即出队
        }
        if (!changed)
            return
        items = next
        _bump()
        _save()
        _ensureTick()
        for (let i = 0; i < fired.length; i++) {
            const it = fired[i]
            root.reminderFired({
                id: it.id,
                title: it.title,
                at: it.at,
                mode: it.mode
            })
        }
    }

    // ---- 持久化（Todo 口径）----
    function _save() {
        if (!_storeReady) {
            _dirty = true
            return
        }
        const payload = JSON.stringify({ items: items })
        _suppressLoad = true
        writeFile.command = [
            "bash", "-c",
            "python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2]+chr(10))' \"$1\" \"$2\"",
            "_",
            root.filePath,
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
            const now = Date.now()
            const restored = []
            const list = Array.isArray(d.items) ? d.items : []
            for (let i = 0; i < list.length; i++) {
                const it = list[i]
                if (!it || !it.at)
                    continue
                const atMs = _parseAt(it.at)
                if (atMs < 0)
                    continue
                const mode = it.mode === "daily" || it.mode === "date" ? it.mode : "once"
                let dateMs = -1
                if (mode === "date") {
                    dateMs = _parseDate(it.date)
                    if (dateMs < 0)
                        continue
                }
                const nextAt = _nextFire(atMs, mode, dateMs, now)
                // once/date 已过点：错过的提醒不补响
                if (nextAt <= now && mode !== "daily")
                    continue
                restored.push({
                    id: it.id || (Date.now().toString(36) + Math.random().toString(36).slice(2, 6)),
                    title: String(it.title || "提醒"),
                    mode: mode,
                    at: String(it.at),
                    date: mode === "date" ? String(it.date || "") : "",
                    atMs: atMs,
                    dateMs: dateMs,
                    nextAt: nextAt
                })
            }
            items = restored
            _bump()
            _ensureTick()
        } catch (e) {
            console.warn("[Reminder] parse failed:", e)
        }
    }

    Process {
        id: writeFile
        onExited: (code) => {
            if (code !== 0)
                console.warn("[Reminder] write failed, code=", code)
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
        path: root.filePath
        preload: true
        // 不 watch：避免外部写盘回读把内存态打回旧内容
        watchChanges: false
        atomicWrites: true
        onLoaded: root._loadFromText(text())
    }
}
