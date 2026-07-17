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
import qs.data.service

Singleton {
    id: root

    // Hub
    property bool showHub: false
    property int hubTabIndex: 0
    property int hubLastOpenIndex: 0

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

    readonly property bool isHubMode: showHub
    // 手动歌词压 toast；自动歌词让路给 toast（对齐旧 DI）
    readonly property bool isNotifMode: notifCount > 0 && !showLyrics && !showHub
    readonly property bool isLyricsMode:
        (showLyrics || (autoLyrics && !lyricsHoverRestore))
        && !showHub && !isNotifMode
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
        showHub = false
    }

    function closeTransient() {
        showLyrics = false
        // autoLyrics 由媒体逻辑维护，这里不强制关
    }

    function openHubTab(index) {
        const i = Math.max(0, Math.min(4, Number(index) || 0))
        if (!showHub) {
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
            showHub = false
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
        openHubTab(4)
        return "SWITCHER_OPENED"
    }

    function wallpaper() {
        openHubTab(2)
        return "WALLPAPER_OPENED"
    }

    function media() {
        openHubTab(1)
        return "MEDIA_OPENED"
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
