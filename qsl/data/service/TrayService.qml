pragma Singleton

// ============================================================
// 托盘折叠 — TrayService
// ============================================================
// 默认常驻：linuxqq / wechat / fcitx / splayer（模糊匹配 id/title/icon）
// 其余进 overflow；菜单可 pin/unpin，覆盖写入 ~/.cache/qsl/tray.json
// 过滤 Passive；无常驻轮询
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/qsl"
    readonly property string filePath: cacheDir + "/tray.json"

    // 默认常驻模式（子串匹配）
    readonly property var defaultPatterns: [
        "linuxqq", "qq", "wechat", "weixin", "fcitx", "splayer"
    ]

    property var extraPinnedIds: []
    property var extraUnpinnedIds: []
    property bool storeReady: false
    property bool filterPassive: true

    property var pinnedItems: []
    property var unpinnedItems: []

    function itemHaystack(item) {
        if (!item)
            return ""
        return [
            item.id || "",
            item.tooltipTitle || "",
            item.title || "",
            item.icon || ""
        ].join(" ").toLowerCase()
    }

    function matchesDefault(item) {
        const hay = root.itemHaystack(item)
        if (!hay.length)
            return false
        for (let i = 0; i < root.defaultPatterns.length; i++) {
            const p = root.defaultPatterns[i]
            // 避免裸 "qq" 误伤：要求 linuxqq/qq 作为词片段
            if (p === "qq") {
                if (hay.indexOf("linuxqq") >= 0
                        || hay.indexOf("qq") >= 0)
                    return true
                continue
            }
            if (hay.indexOf(p) >= 0)
                return true
        }
        return false
    }

    function isPinned(item) {
        if (!item)
            return false
        const id = String(item.id || "")
        if (id.length && root.extraUnpinnedIds.indexOf(id) >= 0)
            return false
        if (id.length && root.extraPinnedIds.indexOf(id) >= 0)
            return true
        return root.matchesDefault(item)
    }

    function rebuild() {
        const raw = SystemTray.items.values || []
        const pinned = []
        const unpinned = []
        for (let i = 0; i < raw.length; i++) {
            const item = raw[i]
            if (!item)
                continue
            if (root.filterPassive && item.status === Status.Passive)
                continue
            if (root.isPinned(item))
                pinned.push(item)
            else
                unpinned.push(item)
        }
        root.pinnedItems = pinned
        root.unpinnedItems = unpinned
    }

    function isPinnedId(itemId) {
        if (!itemId)
            return false
        for (let i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i] && root.pinnedItems[i].id === itemId)
                return true
        }
        return false
    }

    function togglePin(itemId) {
        if (!itemId || !String(itemId).length)
            return

        const id = String(itemId)
        const currentlyPinned = root.isPinnedId(id)
        let pinned = root.extraPinnedIds.slice()
        let unpinned = root.extraUnpinnedIds.slice()

        if (currentlyPinned) {
            const pi = pinned.indexOf(id)
            if (pi >= 0)
                pinned.splice(pi, 1)
            if (unpinned.indexOf(id) < 0)
                unpinned.push(id)
        } else {
            const ui = unpinned.indexOf(id)
            if (ui >= 0)
                unpinned.splice(ui, 1)
            if (pinned.indexOf(id) < 0)
                pinned.push(id)
        }

        root.extraPinnedIds = pinned
        root.extraUnpinnedIds = unpinned
        root.save()
        root.rebuild()
    }

    function save() {
        if (!root.storeReady)
            return
        configFile.setText(JSON.stringify({
            "extraPinnedIds": root.extraPinnedIds,
            "extraUnpinnedIds": root.extraUnpinnedIds,
            "filterPassive": root.filterPassive
        }, null, 2))
    }

    function loadFromObject(parsed) {
        root.extraPinnedIds = Array.isArray(parsed.extraPinnedIds)
            ? parsed.extraPinnedIds.filter(x => typeof x === "string" && x.length)
            : []
        root.extraUnpinnedIds = Array.isArray(parsed.extraUnpinnedIds)
            ? parsed.extraUnpinnedIds.filter(x => typeof x === "string" && x.length)
            : []
        if (typeof parsed.filterPassive === "boolean")
            root.filterPassive = parsed.filterPassive
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged() { root.rebuild() }
    }

    // ObjectModel 插入/删除时 values 长度会变
    property int _itemCount: (SystemTray.items.values || []).length
    on_ItemCountChanged: root.rebuild()

    Component.onCompleted: root.rebuild()

    Process {
        id: ensureDir
        command: ["mkdir", "-p", root.cacheDir]
        running: true
        onExited: {
            root.storeReady = true
            configFile.reload()
        }
    }

    FileView {
        id: configFile
        path: root.filePath
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            try {
                root.loadFromObject(JSON.parse(configFile.text().trim() || "{}"))
            } catch (e) {
                console.warn("TrayService load failed:", e)
                root.loadFromObject({})
            }
            root.rebuild()
        }
        onLoadFailed: {
            root.loadFromObject({})
            root.rebuild()
        }
    }
}
