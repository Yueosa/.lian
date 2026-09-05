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
// 服务层内部的第一条依赖（第 9 轮）。只在 syncLyrics() 的函数体里用，不是绑定，
// 所以 Lyrics 单例仍然是「第一次真的要歌词时」才实例化——它会拉起一个后端进程，
// 不能因为顶栏用了 Media 就跟着起来。同层依赖必须无环：Lyrics 不许反过来认识 Media。
import qs.data.service

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

    // ============================================================
    // 当前曲目的取值面
    // ============================================================
    // 第 9 轮加的。在此之前 MediaPage 和 LockContent 各自维护了一份
    // `player ? (player.trackTitle || …) : …` 的派生属性——**两份逐行同构**，
    // 连成员访问的次数直方图都一模一样（14 个成员，次数逐项相同）。全树只此
    // 一处「同一份解引用抄了两遍」，所以抽一次省两处。
    //
    // 空占位串不在这儿定：锁屏没播放器时要显示空，媒体页要显示「未知曲目」，
    // 那是各自的呈现决定。服务一律给 "" / 0 / false。

    readonly property bool hasActive: !!active
    readonly property bool isMusic: isMusicPlayer(active)

    readonly property string trackTitle: active ? (active.trackTitle || "") : ""
    readonly property string trackArtist: active ? (active.trackArtist || "") : ""
    readonly property string trackArtUrl: active ? (active.trackArtUrl || "") : ""
    readonly property real trackLength: active ? (Number(active.length) || 0) : 0

    readonly property bool playing: !!(active && active.isPlaying)
    readonly property bool canSeek: !!(active && active.canSeek)
    readonly property bool shuffleOn: !!(active && active.shuffle)
    readonly property bool shuffleOk: !!(active && active.shuffleSupported)
    readonly property bool loopOk: !!(active && active.loopSupported)

    // 循环状态对外给两个 bool 而不是 MprisLoopState。调用点只有两种用法
    // （图标选 repeat_one 还是 repeat、按钮亮不亮），给枚举等于逼着 UI 也去
    // import Quickshell.Services.Mpris——那正是要消掉的东西。
    readonly property bool loopOn: !!(active && active.loopState !== MprisLoopState.None)
    readonly property bool loopOne: !!(active && active.loopState === MprisLoopState.Track)

    // position 不发通知，绑不住，只能主动读。单位跟 trackLength 一致（可能是
    // 微秒，见 formatTime）。
    function position() {
        return Number(active ? active.position : 0) || 0
    }

    // MPRIS 各家给的单位不统一：有的秒有的微秒。10 万这个阈值等于「超过 27 小时
    // 的曲子」，现实里不存在，所以拿它当分界比信 metadata 靠谱。
    function formatTime(sec) {
        let s = Number(sec) || 0
        if (s > 100000)
            s = s / 1000000
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + String(r).padStart(2, "0")
    }

    // ============================================================
    // 控制面
    // ============================================================
    // 名字带 Track 后缀是为了跟 nextPlayer / previousPlayer 区分开——
    // 那两个换的是播放器，这两个换的是曲目。

    function playPause() {
        if (active)
            active.togglePlaying()
    }

    function nextTrack() {
        if (active)
            active.next()
    }

    function previousTrack() {
        if (active)
            active.previous()
    }

    // 传 0..1 的比例而不是绝对位置：调用点是进度条，它天然知道的是比例，
    // 让它自己乘 trackLength 就又把单位问题漏回 UI 了。
    function seekFraction(ratio) {
        if (!active || !active.canSeek)
            return
        const r = Math.max(0, Math.min(1, Number(ratio) || 0))
        active.position = r * trackLength
    }

    function toggleShuffle() {
        if (active && active.shuffleSupported)
            active.shuffle = !active.shuffle
    }

    function cycleLoop() {
        if (!active || !active.loopSupported)
            return
        if (active.loopState === MprisLoopState.None)
            active.loopState = MprisLoopState.Playlist
        else if (active.loopState === MprisLoopState.Playlist)
            active.loopState = MprisLoopState.Track
        else
            active.loopState = MprisLoopState.None
    }

    // ============================================================
    // 歌词接线
    // ============================================================
    // 也是两边逐字节相同的一份。放在 Media 而不是 Lyrics：Lyrics 现在是参数化的
    // （fetch(title, artist, playerName, mediaUrl)），谁都能用；让它反过来认识
    // Media 就只能伺候当前播放器了。知道「当前是哪个播放器」的是 Media，所以由
    // 它来推。
    //
    // 不做成自动触发：拉歌词由 Lyrics.acquire/release 引用计数管着，没有界面在看
    // 的时候不该去 fetch。触发点仍然由调用方决定，这里只保证推的内容一致。
    function syncLyrics() {
        if (!active) {
            Lyrics.setPlaceholder("")
            return
        }
        if (!isMusic) {
            Lyrics.setPlaceholder(trackTitle || "正在播放")
            return
        }
        Lyrics.fetch(trackTitle, trackArtist, playerctlName(active), trackUrl(active))
    }

    // 当前曲目换了（标题或艺人变了，或者换了播放器）。给需要跟着刷新的调用点用，
    // 省得它们把 Media.active 当 Connections 的 target 再自己盯一遍。
    signal trackChanged()

    onActiveChanged: trackChanged()

    // 播放器主动报告位置跳变（seek）。歌词那边有 100ms 轮询兜底，但接这个信号
    // 能在拖完进度条的当拍就跟上，不用等下一格。
    signal seeked()

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

    // lyrics-fetch / playerctl 用的实例名（大小写敏感；Identity「SPlayer」会失败）
    // org.mpris.MediaPlayer2.splayer.instance8090 → splayer.instance8090
    function playerctlName(player) {
        if (!player)
            return ""
        const bus = String(player.dbusName || "").trim()
        const prefix = "org.mpris.MediaPlayer2."
        if (bus.startsWith(prefix) && bus.length > prefix.length)
            return bus.slice(prefix.length)
        const id = getIdentity(player)
        if (!id || id === "No Media")
            return ""
        return id.toLowerCase()
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
            function onTrackTitleChanged() {
                root._bump()
                if (modelData === root.active)
                    root.trackChanged()
            }
            function onTrackArtistChanged() {
                if (modelData === root.active)
                    root.trackChanged()
            }
            function onPositionChanged() {
                if (modelData === root.active)
                    root.seeked()
            }
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
