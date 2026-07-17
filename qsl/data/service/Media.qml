pragma Singleton

// ============================================================
// 媒体服务 — Media
// ============================================================
// 只做「选哪个播放器」+ 展示名 / 是否音乐型；曲目字段直接用 MprisPlayer。
// IPC mediatoggle/prev/next 走 active。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property int count: list.length

    property var manualActive: null

    readonly property MprisPlayer active: {
        if (manualActive)
            return manualActive
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    readonly property string activeIdentity: getIdentity(active)
    readonly property string activeIdentityIcon: getIdentityIcon(active)

    function nextPlayer() {
        if (list.length <= 1)
            return
        const idx = list.indexOf(active)
        manualActive = list[(idx + 1) % list.length]
    }

    function previousPlayer() {
        if (list.length <= 1)
            return
        const idx = list.indexOf(active)
        manualActive = list[(idx - 1 + list.length) % list.length]
    }

    function selectPlayer(player) {
        manualActive = player || null
    }

    function getIdentity(player) {
        if (!player)
            return "No Media"
        const rawIdentity = ((player.identity || "") + "").trim()
        const desktop = ((player.desktopEntry || "") + "").trim()
        const bus = ((player.dbusName || "") + "").trim()
        const source = rawIdentity.length > 0 ? rawIdentity
            : (desktop.length > 0 ? desktop : bus)
        if (!source.length)
            return "No Media"
        const lower = source.toLowerCase()
        if (lower.includes("chrome") || lower.includes("chromium"))
            return "Browser"
        if (lower.includes("firefox"))
            return "Firefox"
        if (lower.includes("spotify"))
            return "Spotify"
        if (lower.includes("splayer"))
            return "SPlayer"
        if (lower.includes("vlc"))
            return "VLC"
        if (lower.includes("edge"))
            return "Edge"
        if (lower.includes("mpv"))
            return "mpv"
        return source
    }

    function getIdentityIcon(player) {
        const identity = getIdentity(player).toLowerCase()
        if (identity === "no media")
            return "\uf001"
        if (identity === "spotify")
            return "\uf1bc"
        if (identity === "vlc")
            return "\uf03d"
        if (identity === "firefox" || identity === "browser" || identity === "edge")
            return "\uf0ac"
        return "\uf025"
    }

    // 白名单音乐应用才拉歌词；浏览器/视频默认否
    function isMusicPlayer(player) {
        if (!player)
            return false
        const id = getIdentity(player).toLowerCase()
        if (!id || id === "no media")
            return false
        if (id === "browser" || id === "firefox" || id === "edge"
            || id === "vlc" || id === "mpv"
            || id.includes("chrome") || id.includes("chromium")
            || id.includes("youtube") || id.includes("netflix")
            || id.includes("bilibili") || id.includes("video"))
            return false
        if (id === "spotify" || id === "splayer"
            || id.includes("music") || id.includes("audio")
            || id.includes("cmus") || id.includes("audacious")
            || id.includes("rhythmbox") || id.includes("clementine")
            || id.includes("strawberry") || id.includes("elisa")
            || id.includes("lollypop") || id.includes("quod")
            || id.includes("deadbeef") || id.includes("tauon")
            || id.includes("mpd") || id.includes("ncspot")
            || id.includes("amberol") || id.includes("netease")
            || id.includes("qqmusic") || id.includes("yesplaymusic"))
            return true
        return false
    }

    function trackUrl(player) {
        if (!player)
            return ""
        try {
            const md = player.metadata
            if (md && md["xesam:url"])
                return String(md["xesam:url"])
        } catch (e) {}
        return ""
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (!root.manualActive)
                return
            let stillExists = false
            for (let i = 0; i < root.list.length; i++) {
                if (root.list[i] === root.manualActive) {
                    stillExists = true
                    break
                }
            }
            if (!stillExists)
                root.manualActive = null
        }
    }
}
