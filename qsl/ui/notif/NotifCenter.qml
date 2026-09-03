// NotifCenter — N 面板壳（通知中心 / IPC notif），进入模式容器版
// 页面 = 从 rightrail 派生、贴底（bottomrail 上方 16）的一组 RailContainer
// （RailPage 编排：级联派生/收回、Esc/点空白关闭内建）
// 对外 API 与旧卡片版一致：toggle() / openWindow() / closeWindow()
//
// 共享状态：currentApp / clearing / 分组聚合 / 图标回退上移到 notifState，
// 头卡与列表卡各持一半 UI，经 sharedState 属性共用（对齐 Leftbar 惯例）
// Notification 生命周期：开 uiActive+hydrate+refresh；关 uiActive=false；
//   收回动画播完才 release + 回应用列表（对齐旧 contentActive 语义，不闪空列表）

import QtQuick
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

RailPage {
    id: root

    edge: "right"
    valign: "bottom"
    shellNamespace: "qsl-notif"
    containerWidth: 368

    order: ["notif"]
    page: "notif"
    pages: ({
        notif: { title: "通知", containers: [notifHeaderCard, notifListCard] }
    })

    // 列表卡固定吃屏高 50%（用户实测：72% 太高）；在窗口根取 Screen，
    // QtObject 拿不到 Screen 附加对象
    readonly property int listHeight: Math.round(Screen.height * 0.4)

    // ---- 对外 API（shell.qml IPC target "notif" 在用）----

    function toggle() { open ? closeWindow() : openWindow() }

    function openWindow() {
        notifState.resetClear()
        openPage(page)
        Notification.uiActive = true
        Notification.hydrate()
        Notification.refresh()
    }

    // 覆盖基类：补 Notification.uiActive 释放。
    // QML 函数是对象上的属性，基类内部 Esc/点空白/页内 requestClose
    // 调的 root.closeWindow() 会动态派发到本函数
    function closeWindow() {
        if (!open)
            return
        open = false
        Notification.uiActive = false
        Island.restoreFocus()
    }

    // 覆盖基类：在应用详情页时 Esc 先退回列表，再按一次才关窗
    function escPressed() {
        if (notifState.currentApp !== "")
            notifState.backToApps()
        else
            closeWindow()
    }

    // 收回动画播完再清展示数据：容器收回期间尺寸冻结、内容照旧，
    // 播完才 release，避免「列表先空、容器后收」
    onOpenChanged: {
        if (open)
            releaseTimer.stop()
        else
            releaseTimer.restart()
    }

    Timer {
        id: releaseTimer
        repeat: false
        interval: Size.anim.durFx + 60   // 与 RailPage.swapTimer 同口径：等容器 Exit 播完
        onTriggered: {
            Notification.release()
            // 下次开面板回到应用列表，而不是停在上次进的那个应用
            notifState.currentApp = ""
        }
    }

    // ---- 页内两卡共享状态 ----
    QtObject {
        id: notifState

        // 当前进入的应用页；空串表示停在应用列表
        property string currentApp: ""
        property bool clearing: false

        readonly property int listHeight: root.listHeight

        // 清空：只让前 clearAnimMax 条错开右滑，其余直接随 dismissAll 消失
        // （后面那些本来也多在屏外；限制并发动画避免后半段卡顿）
        readonly property int clearAnimMax: 5
        readonly property int clearStaggerMs: 30

        // 分组键用 app_name 而非 notifctl 的 mapped_app：后者只认
        // telegram/discord/wechat/qq 四个，cursor / notify-send / blueman
        // 等等全被归成 system，混在一起没法看（库里这类将近 3800 条）。
        // desktop_entry 也不可靠——同一个 QQ 有带和不带两种记录。
        function appKeyOf(e) {
            return String(e.appName || "系统").toLowerCase()
        }

        // 按应用聚合出列表页的数据。entries 至多 80 条，每次开面板算一遍即可。
        readonly property var appGroups: {
            const src = Notification.entries || []
            const order = []
            const map = ({})
            for (let i = 0; i < src.length; i++) {
                const e = src[i]
                const k = notifState.appKeyOf(e)
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
                    g.icon = notifState.iconSourceFor(e)
                if (!g.preview)
                    g.preview = e.summary || ""
                if (Number(e.receivedAt) > g.latestAt)
                    g.latestAt = Number(e.receivedAt)
            }
            // entries 已是最新在前，order 天然按「各应用最新消息」降序
            return order
        }

        readonly property var currentAppEntries: {
            if (notifState.currentApp === "")
                return []
            const src = Notification.entries || []
            const out = []
            for (let i = 0; i < src.length; i++) {
                if (notifState.appKeyOf(src[i]) === notifState.currentApp)
                    out.push(src[i])
            }
            return out
        }

        readonly property string currentAppName: {
            const g = notifState.appGroups
            for (let i = 0; i < g.length; i++) {
                if (g[i].key === notifState.currentApp)
                    return g[i].name
            }
            return ""
        }

        // 图标三级回退：通知自带 → desktop entry → 应用名。
        // 只用第一级不够，库里三种失败原因都存在：
        //   QQ      传 image://qsimage/424/1 这种进程内句柄，重启即失效
        //   Discord / Telegram  image_path 干脆是空的
        //   cursor  传的是图标名 co.anysphere.cursor，本来就能用
        // 后两级统一转小写：图标主题里的文件名是 qq.png，而 desktop_entry 存的是 "QQ"。
        // 必须先验证图标存不存在：图标 provider 查不到时不会把 Image.status 置为
        // Error，而是交回一张品红/黑格子的占位图，status 照样是 Ready——
        // 于是 fallback 永远不触发，界面上直接糊一块格子。
        // iconPath(name, true) 查不到返回空串，据此提前挡掉。
        function themeIcon(name) {
            if (!name)
                return ""
            return Quickshell.iconPath(name, true) ? "image://icon/" + name : ""
        }

        function iconSourceFor(entry) {
            const p = String(entry.imagePath || "")
            // /tmp 下的图标活不过重启（Chrome 的 scoped_dir、lya 的 tray 图标都在这）：
            // 优先主题图标；都没有再转 file://（文件没了由 Image.Error 兜底成首字母）
            if (p.indexOf("/tmp/") >= 0) {
                const abs = p.startsWith("image://icon/") ? p.slice(13) : p
                const dt = notifState.themeIcon(String(entry.desktopEntry || "").toLowerCase())
                if (dt)
                    return dt
                const at = notifState.themeIcon(String(entry.appName || "").toLowerCase())
                if (at)
                    return at
                return abs.startsWith("/") ? "file://" + abs : ""
            }
            if (p && p.indexOf("image://qsimage") !== 0) {
                if (p.startsWith("file://") || p.startsWith("image://"))
                    return p
                if (p.startsWith("/"))
                    return "file://" + p
                const byName = notifState.themeIcon(p)
                if (byName)
                    return byName
            }
            const d = notifState.themeIcon(String(entry.desktopEntry || "").toLowerCase())
            if (d)
                return d
            return notifState.themeIcon(String(entry.appName || "").toLowerCase())
        }

        function openApp(key) { currentApp = key }
        function backToApps() { currentApp = "" }

        // 该应用当前的全部通知 id，用于「清空本应用」
        function idsOfCurrentApp() {
            const src = notifState.currentAppEntries
            const ids = []
            for (let i = 0; i < src.length; i++)
                ids.push(src[i].notifId)
            return ids
        }

        function resetClear() {
            _clearFinish.stop()
            clearing = false
        }

        function clearAllAnimated() {
            if (clearing || !Notification.hasNotifications)
                return
            clearing = true
            // 用总条数而非列表 count：停在应用列表页时详情列表是空的
            const n = Math.min(Notification.entries.length, clearAnimMax)
            _clearFinish.interval = Size.anim.durNormal + 50 + Math.max(0, n - 1) * clearStaggerMs
            _clearFinish.restart()
        }

        property Timer _clearFinish: Timer {
            repeat: false
            onTriggered: {
                Notification.dismissAll()
                notifState.clearing = false
                root.closeWindow()
            }
        }

        // 进了应用页时，清空键只清该应用；在列表页才是全清
        function clearScoped() {
            if (currentApp === "") {
                clearAllAnimated()
                return
            }
            Notification.dismissMany(idsOfCurrentApp())
            // 清完这个应用后一条都不剩，就没必要再退回一个空列表，直接收起面板
            if (!Notification.hasNotifications)
                root.closeWindow()
            else
                backToApps()
        }
    }

    // ---- 容器装配（顺序即派生顺序）----
    Component { id: notifHeaderCard; NotifHeaderCard { sharedState: notifState } }
    Component { id: notifListCard; NotifListCard { sharedState: notifState } }
}
