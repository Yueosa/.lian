pragma Singleton

// ============================================================
// Island 状态机 — 多屏共享真源
// ============================================================
// 避免每个 PanelWindow 各挂 IpcHandler 导致 Alt/Super+Tab 竞态。
// UI（ui/island/IslandShell.qml）只读这里的属性做 morph。
// ============================================================
// 模式优先级（高→低）：Hub > 手动/自动歌词 > 通知 toast > 时钟
// 无 L2 媒体卡、无音量 OSD。
// ============================================================

import QtQuick
import Quickshell

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

    // 通知 toast（一级；接入后再填 payload）
    property bool notifToast: false
    property string notifTitle: ""
    property string notifBody: ""

    readonly property bool isHubMode: showHub
    readonly property bool isLyricsMode: (showLyrics || autoLyrics) && !lyricsHoverRestore && !showHub
    readonly property bool isNotifMode: notifToast && !isLyricsMode && !showHub
    readonly property bool isCollapsedMode: !showHub && !isLyricsMode && !isNotifMode

    onHubTabIndexChanged: hubLastOpenIndex = hubTabIndex

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

    function clearNotifToast() {
        notifToast = false
        notifTitle = ""
        notifBody = ""
    }

    function pushNotifToast(title, body) {
        notifTitle = String(title || "")
        notifBody = String(body || "")
        notifToast = true
    }
}
