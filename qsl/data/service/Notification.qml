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
//   appGroups         按应用聚合的分组数组（key/name/count/latestAt/icon/preview）
//   appKeyOf(entry)   分组键
//   entriesOfApp(key) 该应用的全部通知
//   appNameOf(key)    该应用的展示名
//   idsOfApp(key)     该应用的通知 id 列表（用于「清空本应用」）
//   loading           list 是否在跑
//   hydrate()         从 JSON 缓存灌入
//   refresh()         notifctl list 刷新
//   dismiss(id)       关单条（协议 id）
//   dismissAll()      清空
//   toggleDnd()
//   iconFor(entry)    图标 URL，空串表示没有可用图标（UI 兜底成首字母）
//   release()         关面板清展示数组（server 保持轻量常驻）
//   signal toastRequested(var payload)  // 一级岛 toast；DnD 时不发
//     payload: { notifId, title, body, appName, desktopEntry, imagePath }
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
// 图标解析走 Icons，见那边的注释
import qs.data.service

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

    // ============================================================
    // 按应用聚合
    // ============================================================
    // 第 9 轮从 ui/notif/NotifCenter.qml 的 notifState 收上来的。那边原来同时
    // 管两类东西：「按应用怎么分组」（领域规则）和「现在停在哪个应用页、清空
    // 波次播到哪儿」（交互状态）。后者留在原地，前者归这里——换个面板来问
    // 同样的问题，不该再算一遍。
    //
    // 分组键用 app_name 而非 notifctl 的 mapped_app：后者只认
    // telegram/discord/wechat/qq 四个，cursor / notify-send / blueman 等等
    // 全被归成 system，混在一起没法看（库里这类将近 3800 条）。
    // desktop_entry 也不可靠——同一个 QQ 有带和不带两种记录。
    function appKeyOf(entry) {
        return String((entry && entry.appName) || "系统").toLowerCase()
    }

    // entries 至多 80 条，每次变动重算一遍即可。
    // entries 已是最新在前，所以 order 天然按「各应用最新消息」降序。
    readonly property var appGroups: {
        const src = entries || []
        const order = []
        const map = ({})
        for (let i = 0; i < src.length; i++) {
            const e = src[i]
            const k = root.appKeyOf(e)
            let g = map[k]
            if (!g) {
                g = {
                    key: k,
                    // 展示用原始大小写，取该应用最新一条的写法
                    name: e.appName || "系统",
                    count: 0,
                    latestAt: 0,
                    icon: "",
                    preview: ""
                }
                map[k] = g
                order.push(g)
            }
            g.count += 1
            if (!g.icon)
                g.icon = root.iconFor(e)
            if (!g.preview)
                g.preview = e.summary || ""
            if (Number(e.receivedAt) > g.latestAt)
                g.latestAt = Number(e.receivedAt)
        }
        return order
    }

    function entriesOfApp(key) {
        if (!key)
            return []
        const src = entries || []
        const out = []
        for (let i = 0; i < src.length; i++) {
            if (root.appKeyOf(src[i]) === key)
                out.push(src[i])
        }
        return out
    }

    function appNameOf(key) {
        const g = root.appGroups
        for (let i = 0; i < g.length; i++) {
            if (g[i].key === key)
                return g[i].name
        }
        return ""
    }

    function idsOfApp(key) {
        const src = root.entriesOfApp(key)
        const ids = []
        for (let i = 0; i < src.length; i++)
            ids.push(src[i].notifId)
        return ids
    }

    // 一级岛 toast：与面板 entries 无关；payload 一次拷贝字符串
    signal toastRequested(var payload)

    // 异步代际：清空/关面板之后，任何在途的 list / cache 结果都作废。
    // notifctl clear 走 execDetached，与在途的 `notifctl list` 没有顺序保证——
    // 老结果落地就会把刚清掉的行重新灌回 entries（清空时「已滑出的行又闪一下」）
    property int _epoch: 0
    property int _inflightEpoch: -1

    function hydrate() {
        _inflightEpoch = _epoch
        listCache.reload()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        _inflightEpoch = _epoch
        listProc.running = true
    }

    function applyParsed(parsed) {
        entries = Array.isArray(parsed) ? parsed : []
    }

    function applyCacheText(raw) {
        // 期间发生过 dismiss/clear/release：这批结果是删除前的快照，丢掉
        if (_inflightEpoch !== _epoch)
            return
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

    // 上面那个是入库时挑存哪条路径，这个是显示时把它变成能用的 URL。
    //
    // 三级回退，只用第一级不够，库里三种失败原因都存在：
    //   QQ                  传 image://qsimage/424/1 这种进程内句柄，重启即失效
    //   Discord / Telegram  image_path 干脆是空的
    //   cursor              传的是图标名 co.anysphere.cursor，本来就能用
    function iconFor(entry) {
        if (!entry)
            return ""
        const p = String(entry.imagePath || "")

        // /tmp 下的图标活不过重启（Chrome 的 scoped_dir、lya 的 tray 图标都在
        // 这）：优先主题图标；都没有再转 file://，文件没了由 Image.Error 兜底
        if (p.indexOf("/tmp/") >= 0) {
            const abs = p.startsWith("image://icon/") ? p.slice(13) : p
            return Icons.themeLower(entry.desktopEntry)
                || Icons.themeLower(entry.appName)
                || Icons.fromPath(abs)
        }

        if (p && p.indexOf("image://qsimage") !== 0) {
            const direct = Icons.fromPath(p)
            if (direct)
                return direct
            // 不转小写：这一级 p 是通知自己给的图标名，大小写按它说的算
            const byName = Icons.theme(p)
            if (byName)
                return byName
        }

        // 后两级统一转小写：图标主题里的文件名是 qq.png，而 desktopEntry 存的是 "QQ"
        return Icons.themeLower(entry.desktopEntry)
            || Icons.themeLower(entry.appName)
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
        _epoch++
        Quickshell.execDetached([root.ctlPath, "dismiss", String(id)])
    }

    // 批量关闭（堆叠整摞收起时用）。逐条调 dismiss 会重建 entries N 次，
    // 每次都触发面板整表重排，这里合并成一次。
    function dismissMany(ids) {
        if (!ids || ids.length === 0)
            return
        const doomed = {}
        for (let i = 0; i < ids.length; i++)
            doomed[ids[i]] = true

        for (let i = trackedNotifications.count - 1; i >= 0; i--) {
            const n = trackedNotifications.get(i)
            if (n && doomed[n.id])
                n.tracked = false
        }

        const keep = []
        for (let i = 0; i < entries.length; i++) {
            if (!doomed[entries[i].notifId])
                keep.push(entries[i])
        }
        entries = keep
        _epoch++

        for (let i = 0; i < ids.length; i++)
            Quickshell.execDetached([root.ctlPath, "dismiss", String(ids[i])])
    }

    function dismissAll() {
        for (let i = trackedNotifications.count - 1; i >= 0; i--) {
            const n = trackedNotifications.get(i)
            if (n)
                n.tracked = false
        }
        entries = []
        _epoch++
        Quickshell.execDetached([root.ctlPath, "clear"])
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled
    }

    function release() {
        // 关面板只清展示拷贝；DB / server 保留
        entries = []
        _epoch++
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
