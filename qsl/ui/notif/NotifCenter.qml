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
import qs.Components
import qs.data.state
import qs.data.service

RailPage {
    id: root

    edge: "right"
    valign: "bottom"
    shellNamespace: "qsl-notif"
    // 互斥组：N：rightrail 下，和 V=右附栏同区
    panelGroup: "right"
    containerWidth: Size.panel.nWidth

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
        openPage(page)   // open=true 同步触发 onOpenChanged → uiActive=true
        // 缓存先上屏（本地文件，快）；notifctl list 的真数据等派生动画播完再灌。
        // entries 是 var 数组，重新赋值 = ListView 整表重置（delegate 全销毁重建
        // + 每行 Notification.iconFor 里的主题图标同步查询重跑一遍）。
        // 开面板时 hydrate/refresh 背靠背来两次，两次整表重置正好压在
        // 容器生长动画上——这是 N 开面板卡顿的主因
        Notification.hydrate()
        refreshDelay.restart()
    }

    Timer {
        id: refreshDelay
        repeat: false
        interval: root.enterAllMs
        onTriggered: {
            if (root.open)
                Notification.refresh()
        }
    }

    // 覆盖基类：补 Notification.uiActive 释放。
    // QML 函数是对象上的属性，基类内部 Esc/点空白/页内 requestClose
    // 调的 root.closeWindow() 会动态派发到本函数
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
        // 挂在 onOpenChanged 而不是重写 closeWindow：重写就得把基类那几行
        // （open=false / Panels.release）抄一遍，而抄漏了 release 就是本文件
        // 曾经的 bug——僵尸条目留在 Panels 里，合并框窗
        // 之后键盘归属会卡死在一个已经关掉的面板上（详见 Panels 的焦点栈）
        Notification.uiActive = open
        if (open)
            releaseTimer.stop()
        else
            releaseTimer.restart()
    }

    Timer {
        id: releaseTimer
        repeat: false
        interval: root.exitAllMs   // 与 RailPage.swapTimer 同口径：等本页全部容器 Exit 播完
        onTriggered: {
            // 清空是「先收面板、后真删」：删除必须等列表离屏才做，
            // 否则 entries 变空会把已滑出的行回收进复用池并 resetVisual，
            // 行以 x=0/opacity=1 重新露脸（闪一下又消失的那一下）
            if (notifState.pendingClearAll) {
                notifState.pendingClearAll = false
                Notification.dismissAll()
            }
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
        // 清空已排好队、等面板收完再真删（见 releaseTimer）
        property bool pendingClearAll: false

        readonly property int listHeight: root.listHeight

        // 清空：只让前 clearAnimMax 条错开右滑，其余直接随 dismissAll 消失
        // （后面那些本来也多在屏外；限制并发动画避免后半段卡顿）
        readonly property int clearAnimMax: 5
        readonly property int clearStaggerMs: 30

        // 「按应用怎么分组」是领域规则，第 9 轮挪进了 Notification 服务。
        // 这里只剩「现在停在哪个应用页」这类交互状态，以及把服务那几个
        // 按 key 取数的函数接到 currentApp 上。
        readonly property var appGroups: Notification.appGroups

        // entriesOfApp 是函数，QML 追踪不到它读了 entries；不 void 一下的话
        // 这条绑定只跟着 currentApp 走，来了新通知不会重算
        readonly property var currentAppEntries: {
            void Notification.entries
            return Notification.entriesOfApp(notifState.currentApp)
        }

        readonly property string currentAppName: {
            void Notification.entries
            return Notification.appNameOf(notifState.currentApp)
        }

        function openApp(key) { currentApp = key }
        function backToApps() { currentApp = "" }

        // 该应用当前的全部通知 id，用于「清空本应用」
        function idsOfCurrentApp() {
            return Notification.idsOfApp(notifState.currentApp)
        }

        function resetClear() {
            _clearFinish.stop()
            clearing = false
            pendingClearAll = false
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

        // 滑出波次播完 → 只收面板，不动数据。
        // clearing 保持 true（行留在滑出位，不回弹），真删推到 releaseTimer；
        // clearing 由下次 openWindow 的 resetClear 复位
        property Timer _clearFinish: Timer {
            repeat: false
            onTriggered: {
                notifState.pendingClearAll = true
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
