pragma Singleton

// ============================================================
// 快捷键速查 — Hotkeys
// ============================================================
// asset/hotkeys.json：groups[].sections[].items[]
// 无 Timer；FileView watchChanges
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var groups: []
    property bool ready: false
    property string error: ""

    readonly property string jsonPath: {
        const base = Qt.resolvedUrl("../../asset/hotkeys.json")
        return String(base).replace("file://", "")
    }

    function reload() {
        fileView.reload()
    }

    function groupById(id) {
        const list = groups || []
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].id === id)
                return list[i]
        }
        return null
    }

    function formatKeys(s) {
        // Super+A → Super + A，读着更顺
        return String(s || "").replace(/\s*\+\s*/g, " + ")
    }

    // 展平为 ListView 行：{ kind:"header"|"item", ... }
    function flatRowsOf(groupId) {
        const g = groupById(groupId)
        const rows = []
        if (!g)
            return rows

        const sections = g.sections
        if (Array.isArray(sections) && sections.length > 0) {
            for (let i = 0; i < sections.length; i++) {
                const sec = sections[i]
                if (!sec)
                    continue
                rows.push({
                    kind: "header",
                    title: sec.title || sec.id || ""
                })
                const items = sec.items || []
                for (let j = 0; j < items.length; j++) {
                    const it = items[j]
                    if (!it)
                        continue
                    rows.push({
                        kind: "item",
                        keys: formatKeys(it.keys),
                        desc: it.desc || ""
                    })
                }
            }
            return rows
        }

        // 兼容旧扁平 items
        const items = g.items || []
        for (let k = 0; k < items.length; k++) {
            const it = items[k]
            if (!it)
                continue
            rows.push({
                kind: "item",
                keys: formatKeys(it.keys),
                desc: it.desc || ""
            })
        }
        return rows
    }

    function applyText(raw) {
        try {
            const t = (raw || "").trim()
            if (!t) {
                groups = []
                ready = false
                error = "空文件"
                return
            }
            const data = JSON.parse(t)
            groups = Array.isArray(data.groups) ? data.groups : []
            ready = true
            error = ""
        } catch (e) {
            groups = []
            ready = false
            error = String(e)
            console.warn("Hotkeys: parse failed", e)
        }
    }

    FileView {
        id: fileView
        path: root.jsonPath
        watchChanges: true
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: {
            root.groups = []
            root.ready = false
            root.error = "无法读取 hotkeys.json"
        }
    }

    Component.onCompleted: reload()
}
