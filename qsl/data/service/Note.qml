pragma Singleton

// ============================================================
// 常驻笔记服务 — Note（qsl.md M3）
// ============================================================
// 多篇纯文本笔记：{ id, title, body, updated }，持久化
// ~/.local/share/qsl/note.json（Todo 口径：Process 写 + suppressLoad + mkdir 门）。
//
// 写盘策略（qsl.md 定）：setTitle/setBody 是打字路径，500ms 无输入防抖自动
// 保存——连续打字只在最后一拍落盘；add/remove/flush 立即写。防抖只挡打字流，
// 任何「离开」动作（切笔记 / 退出打字态）都调 flush 当场落盘。
//
// noteIds 只随增删变化：芯片条拿它当 model。setBody/setTitle 每敲一下都会
// 整体重赋值 notes（Todo 的重赋值风格），Repeater 直接吃 notes 会每敲一下
// 重建一遍芯片（第 7 轮「视图吃 JS 数组 = 整体重建」的坑）。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var notes: []   // { id, title, body, updated }
    property var noteIds: []
    property int revision: 0
    property bool _storeReady: false
    property bool _dirty: false
    property bool _suppressLoad: false

    readonly property int count: {
        void revision
        return notes.length
    }

    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"
    readonly property string filePath: _dataDir + "/note.json"

    function _bump() { revision++ }
    function _newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
    }

    function titleOf(id) {
        const n = _find(id)
        return n ? n.title : ""
    }

    // 默认名「笔记 #N」：N 取现有笔记名里的最大编号 + 1（用户定）。
    // 按存量推而不是按 count 推——删掉 #1 后再建不该出现两个「笔记 #2」
    function _defaultTitle(list) {
        let max = 0
        for (let i = 0; i < list.length; i++) {
            const m = /^笔记 #(\d+)$/.exec(String(list[i] && list[i].title || ""))
            if (m) {
                const v = Number(m[1])
                if (v > max)
                    max = v
            }
        }
        return "笔记 #" + (max + 1)
    }

    function add() {
        const item = { id: _newId(), title: _defaultTitle(notes), body: "", updated: Date.now() }
        notes = notes.concat([item])
        noteIds = notes.map(n => n.id)
        _bump()
        _saveNow()
        return item.id
    }

    function remove(id) {
        notes = notes.filter(n => n && n.id !== id)
        noteIds = notes.map(n => n.id)
        _bump()
        _saveNow()
    }

    function setTitle(id, title) {
        const cur = _find(id)
        if (!cur || cur.title === title)
            return
        notes = notes.map(n => n.id === id
            ? Object.assign({}, n, { title: title, updated: Date.now() }) : n)
        _bump()
        _scheduleSave()
    }

    function setBody(id, body) {
        const cur = _find(id)
        if (!cur || cur.body === body)
            return
        notes = notes.map(n => n.id === id
            ? Object.assign({}, n, { body: body, updated: Date.now() }) : n)
        _bump()
        _scheduleSave()
    }

    // 离开动作：停防抖、立刻落盘
    function flush() {
        _saveTimer.stop()
        _saveNow()
    }

    function _find(id) {
        for (let i = 0; i < notes.length; i++) {
            if (notes[i] && notes[i].id === id)
                return notes[i]
        }
        return null
    }

    // ---- 写盘：500ms 防抖 + 立即两路 ----
    function _scheduleSave() {
        _saveTimer.restart()
    }

    Timer {
        id: _saveTimer
        interval: 500
        repeat: false
        onTriggered: root._saveNow()
    }

    function _saveNow() {
        if (!_storeReady) {
            _dirty = true
            return
        }
        const payload = JSON.stringify({ notes: notes })
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
            const restored = []
            const list = Array.isArray(d.notes) ? d.notes : []
            for (let i = 0; i < list.length; i++) {
                const it = list[i]
                if (!it || !it.id)
                    continue
                restored.push({
                    id: String(it.id),
                    title: String(it.title || ""),
                    body: String(it.body || ""),
                    updated: it.updated || 0
                })
            }
            if (restored.length === 0) {
                // 默认就该有一篇新建的笔记（用户定）：一篇不剩时（首次启动
                // 或删光后重启）立一篇空白的，空态不可达
                restored.push({ id: _newId(), title: _defaultTitle(restored),
                                body: "", updated: Date.now() })
            }
            notes = restored
            noteIds = restored.map(n => n.id)
            _bump()
        } catch (e) {
            console.warn("[Note] parse failed:", e)
        }
    }

    Process {
        id: writeFile
        onExited: (code) => {
            if (code !== 0)
                console.warn("[Note] write failed, code=", code)
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
                root._saveNow()
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
