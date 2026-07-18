pragma Singleton

// ============================================================
// 媒体服务 — Media
// ============================================================
// 选播放器：手动指定可被「另一路新开播」抢占；
// 自动：播放中的音乐 > 播放中的其它 > 最近开播 > 列表首项。
// 必须监听每个 player 的 isPlaying（不能只依赖 list 引用）。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property int count: list.length

    property var manualActive: null
    // dbusName → 最近变为 playing 的时间戳
    property var _playStartedAt: ({})
    property int _selectGen: 0

    readonly property MprisPlayer active: {
        void _selectGen
        const players = list
        if (!players || players.length === 0)
            return null

        if (manualActive && _playerInList(manualActive)) {
            let otherPlaying = false
            for (let i = 0; i < players.length; i++) {
                if (players[i] !== manualActive && players[i].isPlaying) {
                    otherPlaying = true
                    break
                }
            }
            // 手动项仍在播，或没有别人在播 → 保留手动
            if (manualActive.isPlaying || !otherPlaying)
                return manualActive
        }

        let best = null
        let bestScore = -1
        let bestTime = -1
        for (let i = 0; i < players.length; i++) {
            const p = players[i]
            const score = _score(p)
            const t = _startedAt(p)
            if (score > bestScore || (score === bestScore && t >= bestTime)) {
                best = p
                bestScore = score
                bestTime = t
            }
        }
        return best
    }

    readonly property string activeIdentity: getIdentity(active)
    readonly property string activeIdentityIcon: getIdentityIcon(active)

    function _playerKey(player) {
        if (!player)
            return ""
        return String(player.dbusName || player.identity || player.desktopEntry || "")
    }

    function _playerInList(player) {
        if (!player)
            return false
        for (let i = 0; i < list.length; i++) {
            if (list[i] === player)
                return true
        }
        return false
    }

    function _startedAt(player) {
        const k = _playerKey(player)
        if (!k)
            return 0
        return Number(root._playStartedAt[k]) || 0
    }

    // 分数越高越优先：播放中音乐 ≫ 播放中非音乐 ≫ 静止音乐 ≫ 其它
    function _score(player) {
        if (!player)
            return -1
        let s = 0
        if (player.isPlaying)
            s += 100
        if (isMusicPlayer(player))
            s += 40
        return s
    }

    function _bump() {
        _selectGen++
    }

    function _notePlaying(player) {
        if (!player)
            return
        const k = _playerKey(player)
        if (!k)
            return
        if (player.isPlaying) {
            const next = Object.assign({}, root._playStartedAt)
            next[k] = Date.now()
            root._playStartedAt = next
            // 另一路开播 → 清手动，让自动抢占
            if (root.manualActive && root.manualActive !== player)
                root.manualActive = null
        }
        root._bump()
    }

    function nextPlayer() {
        if (list.length <= 1)
            return
        const idx = list.indexOf(active)
        manualActive = list[(idx + 1) % list.length]
        _bump()
    }

    function previousPlayer() {
        if (list.length <= 1)
            return
        const idx = list.indexOf(active)
        manualActive = list[(idx - 1 + list.length) % list.length]
        _bump()
    }

    function selectPlayer(player) {
        manualActive = player || null
        _bump()
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

    // 每个 MPRIS 播放器单独盯 isPlaying，否则 active 绑不住抢占
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { root._notePlaying(modelData) }
            function onTrackTitleChanged() { root._bump() }
            Component.onCompleted: {
                if (modelData && modelData.isPlaying)
                    root._notePlaying(modelData)
            }
        }
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.manualActive && !root._playerInList(root.manualActive))
                root.manualActive = null
            root._bump()
        }
    }
}
