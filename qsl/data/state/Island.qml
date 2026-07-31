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
    property bool autoLyrics: false
    property bool lyricsHoverRestore: false

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

    function syncAutoLyrics() {
        // 有播放中的曲目 → 一级歌词优先于时钟
        const p = Media.active
        autoLyrics = !!(p && p.isPlaying)
        if (!autoLyrics)
            lyricsHoverRestore = false
    }

    Connections {
        target: Media
        function onActiveChanged() {
            root.syncAutoLyrics()
            if (Media.active)
                playConn.target = Media.active
            else
                playConn.target = null
        }
    }

    Connections {
        id: playConn
        target: Media.active
        function onIsPlayingChanged() { root.syncAutoLyrics() }
    }

    Component.onCompleted: {
        if (Media.active)
            playConn.target = Media.active
        syncAutoLyrics()
    }

    function closeHub() {
        if (!showHub)
            return
        showHub = false
        // 等岛 morph 完再还焦点，避免关瞬间抢 client 焦点导致闪一下
        if (!_activating)
            hubFocusRestoreTimer.restart()
    }

    Timer {
        id: hubCollapseHoldTimer
        interval: root.hubCollapseHoldMs
        repeat: false
        onTriggered: root.hubCollapseHold = false
    }

    // 与 IslandShell body height Behavior(350) 对齐
    Timer {
        id: hubFocusRestoreTimer
        interval: 360
        repeat: false
        onTriggered: {
            if (!root.showHub && !root._activating)
                root.restoreFocus()
        }
    }

    function _beginHubCollapseHold() {
        hubCollapseHold = true
        hubCollapseHoldTimer.restart()
    }

    // —— Exclusive 层焦点归还 ——
    // Hypr 卸 layer Exclusive 后不会自动 focus 回 client
    property string _focusRestoreAddr: ""

    function captureFocus() {
        const t = Hyprland.activeToplevel
        let a = t ? String(t.address || "") : ""
        if (!a.length && t && t.lastIpcObject && t.lastIpcObject.address)
            a = String(t.lastIpcObject.address)
        if (a.length > 0 && !a.startsWith("0x"))
            a = "0x" + a
        _focusRestoreAddr = a
    }

    function clearFocusCapture() {
        _focusRestoreAddr = ""
        focusRestoreDelay.stop()
        focusRestoreDelay.addr = ""
    }

    function restoreFocus() {
        if (!_focusRestoreAddr.length)
            return
        focusRestoreDelay.addr = _focusRestoreAddr
        _focusRestoreAddr = ""
        focusRestoreDelay.restart()
    }

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

    Timer {
        id: focusRestoreDelay
        property string addr: ""
        interval: 60
        repeat: false
        onTriggered: {
            if (addr.length > 0)
                root.hyprFocusWindow(addr)
            addr = ""
        }
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
        clearFocusCapture()
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
            hubFocusRestoreTimer.stop()
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
        // autoLyrics 由媒体逻辑维护，这里不强制关
    }

    function openHubTab(index) {
        const i = Math.max(0, Math.min(4, Number(index) || 0))
        if (!showHub) {
            captureFocus()
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
