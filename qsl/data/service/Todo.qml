pragma Singleton

// ============================================================
// 待办清单服务 — Todo
// ============================================================
// 两级分组：标签 + 优先级；持久化 ~/.local/share/qsl/todo.json
// 写盘用 Process（FileView.setText 不可靠）；suppressLoad 防 onLoaded 回滚
// revision：强制 UI 刷新（ListView JS 数组 + 完成态重排）
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []
    // 「重要」曾经混在这里当标签用，但它其实是 starred 这个正交维度：
    // 一件事既可以是「开发」又可以重要。已改由页面上独立的星标筛选承担，
    // 标签回归纯分类。预置只给两个，其余用 addTag 自建
    property var tags: ["生活", "开发"]
    property int revision: 0
    property bool _suppressLoad: false
    property bool _storeReady: false
    property bool _dirty: false

    readonly property int count: {
        void revision
        return items.length
    }
    readonly property int doneCount: {
        void revision
        let n = 0
        for (let i = 0; i < items.length; i++) {
            if (items[i] && items[i].done)
                n++
        }
        return n
    }

    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"
    readonly property string filePath: _dataDir + "/todo.json"

    function _bump() {
        revision++
    }

    function add(text, tag, priority) {
        if (!text)
            return
        const item = {
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            text: text,
            // 默认无标签：随手记一笔不该被强行归到某一类里
            tag: tag || "",
            priority: priority !== undefined ? priority : 1,
            done: false,
            starred: false,
            created: Date.now()
        }
        items = items.concat([item])
        _bump()
        _save()
        return item.id
    }

    function toggle(id) {
        const next = []
        for (let i = 0; i < items.length; i++) {
            const it = items[i]
            if (!it)
                continue
            if (it.id === id) {
                next.push(Object.assign({}, it, { done: !it.done }))
            } else {
                next.push(it)
            }
        }
        items = next
        _bump()
        _save()
    }

    function remove(id) {
        items = items.filter(i => i && i.id !== id)
        _bump()
        _save()
    }

    function setTag(id, tag) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { tag: tag }) : i)
        _bump()
        _save()
    }

    function setPriority(id, pri) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { priority: pri }) : i)
        _bump()
        _save()
    }

    function star(id) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { starred: !i.starred }) : i)
        _bump()
        _save()
    }

    function addTag(tag) {
        if (tag && tags.indexOf(tag) === -1) {
            tags = tags.concat([tag])
            _bump()
            _save()
        }
    }

    // 删标签不删事项：被摘掉标签的条目退回无标签，而不是被塞进另一类
    function removeTag(tag) {
        tags = tags.filter(t => t !== tag)
        items = items.map(i => i.tag === tag ? Object.assign({}, i, { tag: "" }) : i)
        _bump()
        _save()
    }

    function clearDone() {
        items = items.filter(i => i && !i.done)
        _bump()
        _save()
    }

    function itemsByTag(tag) {
        void revision
        if (!tag || tag === "")
            return items
        return items.filter(i => i.tag === tag)
    }

    function _save() {
        if (!_storeReady) {
            _dirty = true
            return
        }
        const payload = JSON.stringify({ tags: tags, items: items }, null, 2)
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
            const data = JSON.parse(raw)
            // 迁移：磁盘上还留着把「重要」当标签的旧结构，读回来会把它带回列表。
            // 标记为重要的条目转成 starred，标签位清空
            let migrated = false
            if (Array.isArray(data.tags) && data.tags.length > 0) {
                const clean = data.tags.filter(t => t !== "重要")
                migrated = clean.length !== data.tags.length
                tags = clean.length > 0 ? clean : ["生活", "开发"]
            }
            if (Array.isArray(data.items)) {
                items = data.items.map(i => {
                    if (i && i.tag === "重要") {
                        migrated = true
                        return Object.assign({}, i, { tag: "", starred: true })
                    }
                    return i
                })
            }
            _bump()
            if (migrated)
                _save()
        } catch (e) {
            console.warn("[Todo] JSON parse failed:", e)
        }
    }

    Process {
        id: writeFile
        onExited: (code) => {
            if (code !== 0)
                console.warn("[Todo] write failed, code=", code)
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
        // 不 watch：避免 setText/外部写盘回读把内存态打回旧内容
        watchChanges: false
        atomicWrites: true
        onLoaded: root._loadFromText(text())
    }
}
