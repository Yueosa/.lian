pragma Singleton

// ============================================================
// 托盘服务 — TrayService
// ============================================================
// SNI（StatusNotifierItem）这一侧只有这里知道。UI 拿 items 当 model，
// 拿 iconFor / glyphFor 拿显示内容，不再自己 import SystemTray。
//
// 对外接口：
//   items            托盘条目列表（Repeater 直接吃）
//   isPinned(item)   / inOverflow(item)   常驻还是折叠
//   iconFor(item)    图标 URL，空串表示没有可用图标（由 glyphFor 兜底）
//   glyphFor(item)   Material 字形名，图标不可用时显示
//   setPinned / togglePin 及 *Key / *Item 变体
//   pinSignature / revision   pin 布局变了会变，UI 据此重算
//
// QQ 与 Cursor 的 SNI Id 都是 chrome_status_icon_1，itemKey 必须带 icon/menu
// 写盘用 Process；suppressLoad 防止 onLoaded 回滚
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
// 图标解析走 Icons，见那边的注释
import qs.data.service

Singleton {
    id: root

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/qsl"
    readonly property string filePath: cacheDir + "/tray.json"

    // UI 的 model。别在这儿做过滤——isPinned / inOverflow 是按条目问的，
    // 过滤成两个数组会让 Repeater 在 pin 变动时整体重建（图标重新解码）。
    readonly property var items: SystemTray.items

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

    // ============================================================
    // 显示：图标与字形
    // ============================================================
    // 三级：自带 SVG → 条目自己给的 URL/路径 → 主题图标。都拿不到交回空串，
    // UI 那边转去显示 glyphFor 的字形。
    //
    // 顺序不能换。自带 SVG 排最前是因为这几个应用给的图标本来就不能看
    // （Electron QQ 给的是进程内句柄，重启就失效）；主题图标排最后是因为
    // 它最不准——SNI 的 icon 字段常常是个在本机主题里根本不存在的名字。
    function iconFor(item) {
        if (!item)
            return ""
        const bundled = Icons.bundled(Icons.bundledId(root.itemHaystack(item)))
        if (bundled)
            return bundled
        const raw = String(item.icon || "")
        if (!raw.length)
            return ""
        const asPath = Icons.fromPath(raw)
        if (asPath)
            return asPath
        return Icons.theme(raw) || Icons.themeLower(raw)
    }

    // iconFor 交白卷时显示什么。输入法要看得出是输入法，网络要看得出是网络，
    // 其余一律 apps——不认识的托盘项长一个样比乱猜一个图标强。
    function glyphFor(item) {
        const hay = root.itemHaystack(item)
        if (hay.indexOf("fcitx") >= 0)
            return "keyboard"
        if (hay.indexOf("network-wired") >= 0)
            return "lan"
        return "apps"
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
        // 名字里带 QQ / 腾讯 但 Id 不在 defaultPatterns 里的（换过包名、装了别的
        // 分支版本）也一并常驻。
        //
        // 这后面原本还有一段「Id 含 chrome_status_icon 时再查 qq/tim/opt」——
        // 是死代码：chrome_status_icon 本身就在 defaultPatterns 里，上面那个
        // 循环已经先返回 true 了，永远走不到。删掉。
        const title = String((item && (item.tooltipTitle || item.title)) || "").toLowerCase()
        return title.indexOf("qq") >= 0 || title.indexOf("腾讯") >= 0
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
