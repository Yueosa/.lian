pragma Singleton

// ============================================================
// 待办清单服务 — Todo
// ============================================================
// 两级分组模型：标签（tag）+ 优先级（T0/T1/T2）
// 持久化：FileView + JSON，原子写入 ~/.local/share/qsl/todo.json
//
// 对外接口：
//   items        var[]        全部条目
//   tags         string[]     所有标签列表（含 "重要"）
//   add(text, tag, priority)  添加条目
//   toggle(id)               切换完成状态
//   remove(id)               删除条目
//   setTag(id, tag)          修改标签
//   setPriority(id, pri)     修改优先级
//   star(id)                 切换「重要」标记
//   itemsByTag(tag)          按标签过滤（tag="" 返回全部）
//   count / doneCount        计数
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var items: []
    property var tags: ["重要", "生活", "开发"]
    property int count: items.length
    property int doneCount: items.filter(i => i.done).length

    // ---- CRUD ----

    function add(text, tag, priority) {
        if (!text) return
        const item = {
            id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            text: text,
            tag: tag || "生活",
            priority: priority !== undefined ? priority : 1,
            done: false,
            starred: false,
            created: Date.now()
        }
        items = [...items, item]
        _save()
        return item.id
    }

    function toggle(id) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { done: !i.done }) : i)
        _save()
    }

    function remove(id) {
        items = items.filter(i => i.id !== id)
        _save()
    }

    function setTag(id, tag) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { tag: tag }) : i)
        _save()
    }

    function setPriority(id, pri) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { priority: pri }) : i)
        _save()
    }

    function star(id) {
        items = items.map(i => i.id === id ? Object.assign({}, i, { starred: !i.starred }) : i)
        _save()
    }

    function addTag(tag) {
        if (tag && tags.indexOf(tag) === -1) {
            tags = [...tags, tag]
            _save()
        }
    }

    function removeTag(tag) {
        if (tag === "重要") return
        tags = tags.filter(t => t !== tag)
        items = items.map(i => i.tag === tag ? Object.assign({}, i, { tag: "生活" }) : i)
        _save()
    }

    function itemsByTag(tag) {
        if (!tag || tag === "") return items
        if (tag === "重要") return items.filter(i => i.starred)
        return items.filter(i => i.tag === tag)
    }

    // ---- 持久化 ----

    function _save() {
        const payload = JSON.stringify({ tags: tags, items: items }, null, 2)
        _file.setText(payload)
    }

    function _load() {
        const raw = _file.text()
        if (!raw) return
        try {
            const data = JSON.parse(raw)
            if (Array.isArray(data.tags) && data.tags.length > 0)
                tags = data.tags
            if (Array.isArray(data.items))
                items = data.items
        } catch(e) {
            console.warn("[Todo] JSON parse failed:", e)
        }
    }

    readonly property string _dataDir: Quickshell.env("HOME") + "/.local/share/qsl"

    FileView {
        id: _file
        path: root._dataDir + "/todo.json"
        preload: true
        atomicWrites: true
        watchChanges: true
        onLoaded: root._load()
        onFileChanged: root._load()
    }

    Process {
        id: _mkdirProc
        command: ["mkdir", "-p", root._dataDir]
        running: true
    }
}
