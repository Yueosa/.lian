pragma Singleton

// ============================================================
// 通知服务 — Notification
// ============================================================
// 接收：Quickshell NotificationServer（D-Bus）
// 持久化：notifctl + SQLite（~/.local/state/qsl/notif.db）
// 秒开：~/.cache/qsl/notif-list.json
// DnD = 免打扰：仍入库，不发 toastRequested（一级岛不弹）
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
//   signal toastRequested(var payload)  // 一级岛 toast；DnD 时不发
//     payload: { notifId, title, body, appName, desktopEntry, imagePath }
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

    // 常驻 Notification 对象会持有 hints（含应用直传的原始像素数据）和 image 句柄。
    // 面板读的是 SQLite 出来的 entries，从不访问这些对象，全量常驻纯属浪费——
    // 一天下来能攒几千条。保留最近若干条只为让应用「按 id 替换/更新通知」仍生效
    // （进度条类通知依赖这个），超出的直接释放。
    readonly property int trackedLimit: 32

    // 仅面板打开时维护 entries，避免关窗后仍堆内存
    property bool uiActive: false
    property bool dndEnabled: false
    property var entries: []
    property bool loading: false

    // 一级岛 toast：与面板 entries 无关；payload 一次拷贝字符串
    signal toastRequested(var payload)

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

    // 释放最旧的常驻通知，直到不超过上限。
    // 按 id 取最旧而非按下标，trackedNotifications 的排列顺序无文档保证。
    function trimTracked() {
        const list = server.trackedNotifications
        if (!list)
            return
        let guard = 0
        while (list.count > root.trackedLimit && guard++ < 512) {
            let oldest = null
            let oldestId = Infinity
            for (let i = 0; i < list.count; i++) {
                const n = list.get(i)
                if (n && Number(n.id) < oldestId) {
                    oldestId = Number(n.id)
                    oldest = n
                }
            }
            if (!oldest)
                return
            oldest.tracked = false
        }
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
            root.trimTracked()
            if (root.uiActive)
                root.prependLive(notification)
            // DnD 仍入库，只压制岛上 toast
            if (!root.dndEnabled) {
                root.toastRequested({
                    notifId: notification.id,
                    title: notification.summary || "",
                    body: notification.body || "",
                    appName: notification.appName || "",
                    desktopEntry: notification.desktopEntry || "",
                    imagePath: root.pickImagePath(notification)
                })
            }        }
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
