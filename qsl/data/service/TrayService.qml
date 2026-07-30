pragma Singleton

// ============================================================
// 托盘折叠 — TrayService
// ============================================================
// QQ 与 Cursor 的 SNI Id 都是 chrome_status_icon_1，itemKey 必须带 icon/menu
// 写盘用 Process；suppressLoad 防止 onLoaded 回滚
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/qsl"
    readonly property string filePath: cacheDir + "/tray.json"

    // QQ / Cursor 同为 chrome_status_icon_1：一并常驻（暂不拆分）
    readonly property var defaultPatterns: [
        "linuxqq", "wechat", "weixin", "fcitx", "splayer",
        "chrome_status_icon"
    ]
    readonly property var defaultCollapsePatterns: [
    ]

    property var extraPinnedIds: []
    property var extraUnpinnedIds: []
    property bool storeReady: false
    property bool filterPassive: true
    property bool dirty: false
    property bool suppressLoad: false
    property int revision: 0
    property string pinSignature: ""
    property int unpinnedCount: 0

    function itemKey(item) {
        if (!item)
            return ""
        const id = String(item.id || "")
        const icon = String(item.icon || "")
        const tip = String(item.tooltipTitle || item.title || "")
        let uniq = icon
        if (!uniq.length)
            uniq = tip
        if (!uniq.length && item.menu)
            uniq = String(item.menu)
        if (id.length || uniq.length)
            return id + "\x1f" + uniq
        return ""
    }

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

    function matchesCollapse(item) {
        const hay = root.itemHaystack(item)
        if (!hay.length)
            return false
        for (let i = 0; i < root.defaultCollapsePatterns.length; i++) {
            if (hay.indexOf(root.defaultCollapsePatterns[i]) >= 0)
                return true
        }
        return false
    }

    function matchesDefault(item) {
        if (root.matchesCollapse(item))
            return false
        const hay = root.itemHaystack(item)
        if (!hay.length)
            return false
        for (let i = 0; i < root.defaultPatterns.length; i++) {
            if (hay.indexOf(root.defaultPatterns[i]) >= 0)
                return true
        }
        const title = String((item && (item.tooltipTitle || item.title)) || "").toLowerCase()
        if (title.indexOf("qq") >= 0 || title.indexOf("腾讯") >= 0)
            return true
        if (String(item.id || "").toLowerCase().indexOf("chrome_status_icon") >= 0) {
            if (hay.indexOf("qq") >= 0 || hay.indexOf("tim") >= 0 || hay.indexOf("/opt/qq") >= 0)
                return true
        }
        return false
    }

    function isListed(item) {
        if (!item)
            return false
        if (root.filterPassive && item.status === Status.Passive)
            return false
        return true
    }

    function isPinned(item) {
        if (!root.isListed(item))
            return false
        const key = root.itemKey(item)
        if (key.length && root.extraPinnedIds.indexOf(key) >= 0)
            return true
        if (key.length && root.extraUnpinnedIds.indexOf(key) >= 0)
            return false
        if (root.matchesCollapse(item))
            return false
        return root.matchesDefault(item)
    }

    function inOverflow(item) {
        return root.isListed(item) && !root.isPinned(item)
    }

    function isPinnedKey(key) {
        if (!key || !String(key).length)
            return false
        const k = String(key)
        if (root.extraPinnedIds.indexOf(k) >= 0)
            return true
        if (root.extraUnpinnedIds.indexOf(k) >= 0)
            return false
        const raw = (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : []
        for (let i = 0; i < raw.length; i++) {
            const item = raw[i]
            if (item && root.itemKey(item) === k)
                return root.isPinned(item)
        }
        return false
    }

    function setPinned(key, wantPinned) {
        if (!key || !String(key).length)
            return false
        const k = String(key)
        const pinned = root.extraPinnedIds.filter(x => x !== k)
        const unpinned = root.extraUnpinnedIds.filter(x => x !== k)
        if (wantPinned)
            pinned.push(k)
        else
            unpinned.push(k)
        root.extraPinnedIds = pinned
        root.extraUnpinnedIds = unpinned
        root.dirty = true
        root.save()
        root.refreshCounts()
        return true
    }

    function setItemPinned(item, wantPinned) {
        return root.setPinned(root.itemKey(item), wantPinned)
    }

    function togglePinKey(key) {
        return root.setPinned(key, !root.isPinnedKey(key))
    }

    function togglePinItem(item) {
        if (!item)
            return false
        return root.setItemPinned(item, !root.isPinned(item))
    }

    function togglePin(itemId) {
        return root.togglePinKey(itemId)
    }

    function isPinnedId(itemId) {
        return root.isPinnedKey(itemId)
    }

    function refreshCounts() {
        const raw = (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : []
        let n = 0
        const pinnedKeys = []
        for (let i = 0; i < raw.length; i++) {
            const item = raw[i]
            if (!item)
                continue
            if (root.inOverflow(item))
                n++
            else if (root.isPinned(item))
                pinnedKeys.push(root.itemKey(item))
        }
        pinnedKeys.sort()
        root.unpinnedCount = n
        root.pinSignature = pinnedKeys.join("\x1e")
            + "\x1eP:" + root.extraPinnedIds.join(",")
            + "\x1eU:" + root.extraUnpinnedIds.join(",")
        root.revision = root.revision + 1
    }

    function save() {
        if (!root.storeReady) {
            root.dirty = true
            return
        }
        const payload = JSON.stringify({
            "extraPinnedIds": root.extraPinnedIds,
            "extraUnpinnedIds": root.extraUnpinnedIds,
            "filterPassive": root.filterPassive
        })
        root.suppressLoad = true
        writeFile.command = [
            "bash", "-c",
            "python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text(sys.argv[2]+chr(10))' \"$1\" \"$2\"",
            "_",
            root.filePath,
            payload
        ]
        writeFile.running = true
        root.dirty = false
    }

    Process {
        id: writeFile
        onExited: (code) => {
            if (code !== 0)
                console.warn("TrayService: write tray.json failed, code=", code)
            Qt.callLater(() => {
                root.suppressLoad = false
            })
        }
    }

    function loadFromObject(parsed) {
        if (root.dirty || root.suppressLoad)
            return
        // 丢掉旧的「裸 chrome_status_icon_1」键（无法区分 QQ/Cursor）
        function cleanKeys(arr) {
            if (!Array.isArray(arr))
                return []
            return arr.filter(x => typeof x === "string" && x.length && x !== "chrome_status_icon_1")
        }
        root.extraPinnedIds = cleanKeys(parsed.extraPinnedIds)
        root.extraUnpinnedIds = cleanKeys(parsed.extraUnpinnedIds)
        if (typeof parsed.filterPassive === "boolean")
            root.filterPassive = parsed.filterPassive
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged() { root.refreshCounts() }
    }

    property int _itemCount: (SystemTray.items.values || []).length
    on_ItemCountChanged: root.refreshCounts()

    Component.onCompleted: root.refreshCounts()

    Process {
        id: ensureDir
        command: ["mkdir", "-p", root.cacheDir]
        running: true
        onExited: {
            root.storeReady = true
            if (root.dirty)
                root.save()
            else
                configFile.reload()
        }
    }

    FileView {
        id: configFile
        path: root.filePath
        atomicWrites: true
        watchChanges: false
        onLoaded: {
            if (root.suppressLoad)
                return
            try {
                root.loadFromObject(JSON.parse(configFile.text().trim() || "{}"))
            } catch (e) {
                console.warn("TrayService load failed:", e)
            }
            if (root.dirty)
                root.save()
            root.refreshCounts()
        }
        onLoadFailed: {
            if (root.suppressLoad)
                return
            root.save()
            root.refreshCounts()
        }
    }
}
