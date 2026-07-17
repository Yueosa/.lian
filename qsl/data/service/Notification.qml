pragma Singleton

// ============================================================
// 通知服务 — Notification
// ============================================================
// 接收：Quickshell NotificationServer（D-Bus）
// 持久化：notifctl + SQLite（~/.local/state/qsl/notif.db）
// 秒开：~/.cache/qsl/notif-list.json
// DnD = 免打扰：仍入库，标记 suppressPopup 给日后 Island toast 用
// ============================================================
// 对外接口：
//   trackedNotifications / hasNotifications / count / dndEnabled
//   uiActive          面板打开时为 true；关闭时不维护 entries
//   entries           活动通知数组（UI 用，最新在前）
//   loading           list 是否在跑
//   hydrate()         从 JSON 缓存灌入
//   refresh()         notifctl list 刷新
//   dismiss(id)       关单条（协议 id）
//   dismissAll()      清空
//   toggleDnd()
//   release()         关面板清展示数组（server 保持轻量常驻）
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property string ctlPath:
        Quickshell.shellDir + "/backend/notif/build/notifctl"
    readonly property string listCachePath:
        Quickshell.env("HOME") + "/.cache/qsl/notif-list.json"

    readonly property var trackedNotifications: server.trackedNotifications
    readonly property bool hasNotifications: entries.length > 0
    readonly property int count: entries.length

    // 仅面板打开时维护 entries，避免关窗后仍堆内存
    property bool uiActive: false
    property bool dndEnabled: false
    property var entries: []
    property bool loading: false

    function hydrate() {
        listCache.reload()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        listProc.running = true
    }

    function applyParsed(parsed) {
        entries = Array.isArray(parsed) ? parsed : []
    }

    function applyCacheText(raw) {
        try {
            const t = (raw || "").trim()
            applyParsed(t.length > 0 ? JSON.parse(t) : [])
        } catch (e) {
            console.warn("Notification: parse cache failed", e)
            applyParsed([])
        }
    }

    function persistIngest(n) {
        const payload = JSON.stringify({
            id: n.id,
            appName: n.appName || "",
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            image: n.image || "",
            appIcon: n.appIcon || "",
            icon: n.icon || ""
        })
        Quickshell.execDetached([root.ctlPath, "ingest", payload])
    }

    function shouldSkip(n) {
        const d = (n.desktopEntry || "").toLowerCase()
        const a = (n.appName || "").toLowerCase()
        return d.indexOf("spotify") >= 0
            || d.indexOf("player") >= 0
            || a.indexOf("spotify") >= 0
    }

    // 面板图标：避开短命的 image://qsimage 句柄（关窗/reload 后失效）
    function pickImagePath(n) {
        const img = n.image || ""
        if (img.indexOf("image://qsimage") === 0)
            return n.appIcon || n.icon || ""
        return img || n.appIcon || n.icon || ""
    }

    function prependLive(n) {
        const row = {
            id: -1,
            notifId: n.id,
            appName: n.appName || "",
            desktopEntry: n.desktopEntry || "",
            summary: n.summary || "",
            body: n.body || "",
            imagePath: root.pickImagePath(n),
            mappedApp: "system",
            receivedAt: Date.now()
        }
        const next = [row]
        for (let i = 0; i < entries.length && next.length < 80; i++)
            next.push(entries[i])
        entries = next
    }

    function dismiss(id) {
        for (let i = 0; i < trackedNotifications.count; i++) {
            const n = trackedNotifications.get(i)
            if (n && n.id === id) {
                n.tracked = false
                break
            }
        }
        const keep = []
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].notifId !== id)
                keep.push(entries[i])
        }
        entries = keep
        Quickshell.execDetached([root.ctlPath, "dismiss", String(id)])
    }

    function dismissAll() {
        for (let i = trackedNotifications.count - 1; i >= 0; i--) {
            const n = trackedNotifications.get(i)
            if (n)
                n.tracked = false
        }
        entries = []
        Quickshell.execDetached([root.ctlPath, "clear"])
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled
    }

    function release() {
        // 关面板只清展示拷贝；DB / server 保留
        entries = []
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyImagesSupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: function(notification) {
            if (root.shouldSkip(notification))
                return
            notification.tracked = true
            root.persistIngest(notification)
            if (root.uiActive)
                root.prependLive(notification)
        }
    }

    FileView {
        id: listCache
        path: root.listCachePath
        watchChanges: false
        onLoaded: root.applyCacheText(text())
        onLoadFailed: {
            if (root.entries.length === 0)
                root.applyParsed([])
        }
    }

    Process {
        id: listProc
        command: [root.ctlPath, "list", "--limit", "80"]
        stdout: StdioCollector {
            onStreamFinished: root.applyCacheText(this.text)
        }
        onExited: root.loading = false
    }
}
