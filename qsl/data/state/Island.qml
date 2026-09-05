pragma Singleton

// ============================================================
// Island 状态机 — 多屏共享真源
// ============================================================
// 避免每个 PanelWindow 各挂 IpcHandler 导致 Alt/Super+Tab 竞态。
// UI（ui/island/IslandShell.qml）只读这里的属性做 morph。
// ============================================================
// 模式优先级（高→低）：Hub > 手动歌词 > 通知 toast > 自动歌词 > 时钟
// 通知 toast：最多堆叠 3 条（对齐旧 DI popupModel）
// 无 L2 媒体卡、无音量 OSD。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.data.service

Singleton {
    id: root

    // Hub
    property bool showHub: false
    property int hubTabIndex: 0
    property int hubLastOpenIndex: 0

    // 一级岛层级：默认 Top（Hyprland 全屏窗口会盖住 Top、盖不住 Overlay）。
    // 开启后收起态也提到 Overlay，全屏游戏时歌词/通知仍浮在最上层（Ctrl+G 切换）。
    // 开销：仅影响 layer-shell 挂载层，无绘制/内存变化。
    property bool overlayLayer: false

    // 歌词（一级）
    property bool showLyrics: false
    // 纯绑定收敛：读 Media.active 与其 isPlaying，两者任一变化都会重算。
    // 勿改回命令式 sync——MPRIS 上同时挂多个播放器（如 chromium + splayer）时，
    // 单点 Connections 的 target 会被重新赋值而断掉绑定，暂停信号丢失后
    // autoLyrics 卡在 true，Cava 的 relay/reader 子进程会一直空转。
    readonly property bool autoLyrics: {
        const p = Media.active
        return !!(p && p.isPlaying)
    }
    property bool lyricsHoverRestore: false

    onAutoLyricsChanged: {
        if (!autoLyrics)
            lyricsHoverRestore = false
    }

    // 通知 toast 队列（最新在前；≤3；ListModel 保条目身份 → Timer 不重置）
    readonly property int notifToastLimit: 3
    readonly property int notifToastMs: 5000
    property int _toastSeq: 0

    ListModel {
        id: notifModel
    }

    readonly property alias notifToasts: notifModel
    readonly property int notifCount: notifModel.count
    // 旧 DI：notifH = count*70 + 20（高度本身不再乘 islandScale）
    readonly property int notifH: notifCount > 0 ? (notifCount * 70 + 20) : 0

    // Hub 收起宽限期：先回时钟一级岛，再允许通知/歌词抢占（避免 morph 中歌词被拉宽）
    property bool hubCollapseHold: false
    readonly property int hubCollapseHoldMs: 1000

    readonly property bool isHubMode: showHub
    // 手动歌词压 toast；自动歌词让路给 toast（对齐旧 DI）
    readonly property bool isNotifMode: notifCount > 0 && !showLyrics && !showHub && !hubCollapseHold
    readonly property bool isLyricsMode:
        (showLyrics || (autoLyrics && !lyricsHoverRestore))
        && !showHub && !isNotifMode && !hubCollapseHold
    readonly property bool isCollapsedMode: !showHub && !isLyricsMode && !isNotifMode

    onHubTabIndexChanged: hubLastOpenIndex = hubTabIndex

    Connections {
        target: Notification
        function onToastRequested(payload) {
            root.pushNotifToast(payload)
        }
    }

    function closeHub() {
        if (!showHub)
            return
        showHub = false
        // 曾经这里要起一个 360ms 的定时器，等 morph 播完再 spawn hyprctl 把焦点
        // 还给应用（Exclusive 抢走了不会自己还）。框窗改用 HyprlandFocusGrab
        // 之后没有东西被抢，也就没有东西要还：grab 的存活跟着 hubMounted，
        // 本来就横跨整段收起动画，时序由绑定管，不用再写定时器
    }

    Timer {
        id: hubCollapseHoldTimer
        interval: root.hubCollapseHoldMs
        repeat: false
        onTriggered: root.hubCollapseHold = false
    }

    function _beginHubCollapseHold() {
        hubCollapseHold = true
        hubCollapseHoldTimer.restart()
    }

    // —— Exclusive 层焦点归还：已删 ——
    // 原来这儿有一套「开窗前记下当前窗口地址、关窗后 spawn hyprctl 送回去」，
    // 因为 Hypr 卸 layer Exclusive 后不会自动 focus 回 client。
    // 合并框窗改用 OnDemand + HyprlandFocusGrab 之后就不需要了——grab 从不抢
    // 应用焦点，自然没有归还这回事。第 7 轮 A / Z / X 三个独立窗全部搬进框窗，
    // 最后一个用户（WebSearch）也废掉了，于是整段（含 focusRestoreDelay）删掉。
    // 下面的 hyprEval / hyprFocusWindow 留着：Switcher 跳窗在用

    // Hyprland Lua：Hyprland.dispatch("focuswindow …") 会变成
    // hl.dispatch(focuswindow …) 无引号而炸；走 hyprctl eval + hl.dsp
    function hyprEval(luaExpr) {
        Quickshell.execDetached(["hyprctl", "eval", luaExpr])
    }

    function hyprFocusWindow(addr) {
        const a = _normAddr(addr)
        if (!a.length)
            return
        hyprEval("hl.dispatch(hl.dsp.focus({window='" + a + "'}))")
    }

    function hyprFocusWorkspace(wsId) {
        if (wsId === null || wsId === undefined || isNaN(Number(wsId)))
            return
        hyprEval("hl.dispatch(hl.dsp.focus({workspace=" + Number(wsId) + "}))")
    }

    // —— Switcher 跳窗 ——
    // 焦点目标写在单例：壳层 Enter 可用；Timer 也必须在单例（closeHub 会拆掉页面）。
    property var switcherWsId: null
    property string switcherAddr: ""
    property var switcherToplevel: null

    property var _pendingWsId: null
    property string _pendingAddr: ""
    property var _pendingToplevel: null
    property bool _activating: false

    function _normAddr(addr) {
        let a = String(addr || "")
        if (a.length > 0 && !a.startsWith("0x"))
            a = "0x" + a
        return a
    }

    function _normWsId(wsId) {
        if (wsId === undefined || wsId === null || isNaN(Number(wsId)))
            return null
        return Number(wsId)
    }

    function setSwitcherTarget(wsId, addr, toplevel) {
        switcherWsId = _normWsId(wsId)
        switcherAddr = _normAddr(addr)
        switcherToplevel = toplevel || null
    }

    function clearSwitcherTarget() {
        switcherWsId = null
        switcherAddr = ""
        switcherToplevel = null
    }

    function activateSwitcherFocus() {
        activateWindow(switcherWsId, switcherAddr, switcherToplevel)
    }

    function activateWindow(wsId, addr, toplevel) {
        const id = _normWsId(wsId)
        const a = _normAddr(addr)
        const top = toplevel || null

        if (id === null && a.length === 0 && !top)
            return
        // 忽略销毁期空参二次调用，避免盖掉有效 pending
        if (_activating && a.length === 0 && !top)
            return

        _pendingWsId = id
        _pendingAddr = a
        _pendingToplevel = top
        _activating = true
        showHub = false
        activateDispatch.restart()
    }

    Timer {
        id: activateDispatch
        interval: 100
        repeat: false
        onTriggered: {
            const t = root._pendingToplevel
            if (t) {
                try {
                    if (t.wayland)
                        t.wayland.activate()
                    else if (t.activate)
                        t.activate()
                } catch (e) {}
            }
            if (root._pendingWsId !== null)
                root.hyprFocusWorkspace(root._pendingWsId)
            if (root._pendingAddr.length > 0)
                root.hyprFocusWindow(root._pendingAddr)

            root._pendingWsId = null
            root._pendingAddr = ""
            root._pendingToplevel = null
            root._activating = false
            root.clearSwitcherTarget()
        }
    }

    onShowHubChanged: {
        if (showHub) {
            hubCollapseHold = false
            hubCollapseHoldTimer.stop()
            return
        }
        // 非跳窗关岛时丢掉焦点目标，避免持有 HyprlandToplevel 引用
        if (!_activating)
            clearSwitcherTarget()
        // 关 Hub：先停在时钟一级岛 1s，再让 toast/歌词抢占
        _beginHubCollapseHold()
    }

    function closeTransient() {
        showLyrics = false
        // autoLyrics 是只读绑定，随播放状态自行收敛
    }

    function openHubTab(index) {
        const i = Math.max(0, Math.min(4, Number(index) || 0))
        if (!showHub) {
            // 不再 captureFocus()：grab 不抢应用焦点，没有要记的东西
            closeTransient()
            hubTabIndex = i
            showHub = true
        } else if (hubTabIndex !== i) {
            hubTabIndex = i
        }
    }

    // 已在该 tab → 关；否则打开/切到该 tab
    function toggleHubTab(index) {
        const i = Math.max(0, Math.min(4, Number(index) || 0))
        if (showHub && hubTabIndex === i) {
            closeHub()
            return false
        }
        openHubTab(i)
        return true
    }

    function resolveHubDefaultTab() {
        // 恢复 Media / Wallpaper / Weather；Switcher 或未知 → Overview
        if (hubLastOpenIndex === 1 || hubLastOpenIndex === 2 || hubLastOpenIndex === 3)
            return hubLastOpenIndex
        return 0
    }

    function hub() {
        return toggleHubTab(resolveHubDefaultTab()) ? "HUB_OPENED" : "HUB_CLOSED"
    }

    function switcher() {
        return toggleHubTab(4) ? "SWITCHER_OPENED" : "SWITCHER_CLOSED"
    }

    function wallpaper() {
        openHubTab(2)
        return "WALLPAPER_OPENED"
    }

    function media() {
        openHubTab(1)
        return "MEDIA_OPENED"
    }

    function weather() {
        openHubTab(3)
        return "WEATHER_OPENED"
    }

    function toggleLayer() {
        overlayLayer = !overlayLayer
        return overlayLayer ? "OVERLAY_ON" : "OVERLAY_OFF"
    }

    function clearNotifIndex(i) {
        const idx = Number(i)
        if (idx >= 0 && idx < notifModel.count)
            notifModel.remove(idx)
    }

    function clearNotifAt(id) {
        const target = Number(id)
        for (let i = 0; i < notifModel.count; i++) {
            if (Number(notifModel.get(i).toastId) === target) {
                notifModel.remove(i)
                return
            }
        }
    }

    // payload: { notifId, title, body, appName, desktopEntry, imagePath }
    function pushNotifToast(payload) {
        const p = payload || {}
        lyricsHoverRestore = false
        _toastSeq++
        notifModel.insert(0, {
            toastId: _toastSeq,
            notifId: p.notifId !== undefined ? Number(p.notifId) : _toastSeq,
            title: String(p.title || ""),
            body: String(p.body || ""),
            appName: String(p.appName || ""),
            desktopEntry: String(p.desktopEntry || ""),
            imagePath: String(p.imagePath || "")
        })
        while (notifModel.count > notifToastLimit)
            notifModel.remove(notifModel.count - 1)
    }
}
