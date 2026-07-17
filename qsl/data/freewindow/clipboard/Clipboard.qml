pragma Singleton

// ============================================================
// 剪贴板数据 — Clipboard
// ============================================================
// 真源仍是 cliphist（磁盘 DB）；本层只缓存 list 元数据 JSON，
// 给 UI 秒开，不复制原图/全文。
//
//   ~/.cache/qsl/clipboard-list.json  ← clipboardctl list 写出
//   ~/.cache/qsl/clipboard-thumbs/    ← 图片缩略图
// ============================================================
// 对外接口：
//   entries / filtered / searchText / loading / empty
//   hydrate()  从 JSON 缓存灌入内存（打开时立刻有数据）
//   refresh()  跑 clipboardctl list，更新缓存 + 内存
//   search() / paste() / clear() / release()
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string ctlPath:
        Quickshell.shellDir + "/backend/clipboard/build/clipboardctl"
    readonly property string listCachePath:
        Quickshell.env("HOME") + "/.cache/qsl/clipboard-list.json"

    property var entries: []
    property var filtered: []
    property string searchText: ""
    property bool loading: false

    // 以磁盘 JSON 为准：无文件或 [] 才算空（不靠瞬时内存）
    readonly property bool empty: entries.length === 0

    function applyParsed(parsed) {
        entries = Array.isArray(parsed) ? parsed : []
        applyFilter()
    }

    function applyCacheText(raw) {
        try {
            const t = (raw || "").trim()
            applyParsed(t.length > 0 ? JSON.parse(t) : [])
        } catch (e) {
            console.warn("Clipboard: parse cache failed", e)
            applyParsed([])
        }
    }

    // 打开窗口：先读缓存（同步观感），再后台 refresh
    function hydrate() {
        listCache.reload()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        listProc.running = true
    }

    function search(query) {
        searchText = query || ""
        applyFilter()
    }

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (q === "") {
            filtered = entries
            return
        }
        const out = []
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            if ((e.preview || "").toLowerCase().indexOf(q) >= 0)
                out.push(e)
        }
        filtered = out
    }

    function paste(id, mime) {
        if (!id)
            return
        Quickshell.execDetached([root.ctlPath, "paste", String(id), mime || ""])
    }

    function clear() {
        Quickshell.execDetached([root.ctlPath, "clear"])
        applyParsed([])
    }

    // 关窗后清内存，减轻 Image/delegate；JSON 仍在磁盘供下次 hydrate
    function release() {
        entries = []
        filtered = []
        searchText = ""
    }

    FileView {
        id: listCache
        path: root.listCachePath
        // 只在 hydrate() 时读盘；不 watch，避免 list 写缓存后重复 parse
        watchChanges: false
        onLoaded: root.applyCacheText(text())
        onLoadFailed: {
            if (root.entries.length === 0)
                root.applyParsed([])
        }
    }

    Process {
        id: listProc
        command: [root.ctlPath, "list", "--limit", "100"]
        stdout: StdioCollector {
            onStreamFinished: {
                // stdout 与落盘 JSON 同内容；先用 stdout 更新，避免等 FileView
                root.applyCacheText(this.text)
            }
        }
        onExited: root.loading = false
    }
}
