pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    // 获取所有可用的播放器数组
    readonly property list<MprisPlayer> list: Mpris.players.values
    
    // 保存用户手动指定的播放器
    property var manualActive: null

    // 核心计算逻辑：优先手动指定 -> 正在播放的 -> 列表第一个 -> null
    readonly property MprisPlayer active: {
        if (manualActive) return manualActive;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    // 监听底层状态：如果用户手动指定的播放器被彻底关掉（进程结束），则清空手动状态，让系统重新接管
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            if (root.manualActive) {
                let stillExists = false;
                for (let i = 0; i < Mpris.players.values.length; i++) {
                    if (Mpris.players.values[i] === root.manualActive) {
                        stillExists = true;
                        break;
                    }
                }
                if (!stillExists) root.manualActive = null;
            }
        }
    }

    // 辅助函数：将底层播放器身份清洗为稳定可显示名称
    function getIdentity(player) {
        if (!player) return "No Media";

        const rawIdentity = ((player.identity || "") + "").trim();
        const desktop = ((player.desktopEntry || "") + "").trim();
        const bus = ((player.dbusName || "") + "").trim();
        const source = rawIdentity.length > 0 ? rawIdentity : (desktop.length > 0 ? desktop : bus);
        if (!source || source.length === 0) return "No Media";

        const lower = source.toLowerCase();
        if (lower.includes("chrome") || lower.includes("chromium")) return "Browser";
        if (lower.includes("firefox")) return "Firefox";
        if (lower.includes("spotify")) return "Spotify";
        if (lower.includes("splayer")) return "SPlayer";
        if (lower.includes("vlc")) return "VLC";
        if (lower.includes("edge")) return "Edge";
        if (lower.includes("mpv")) return "mpv";

        return source;
    }

    function getIdentityIcon(player) {
        const identity = getIdentity(player).toLowerCase();
        if (identity === "no media") return "music_note";
        if (identity === "spotify") return "album";
        if (identity === "vlc") return "movie";
        if (identity === "firefox" || identity === "browser" || identity === "edge") return "language";
        return "audio_file";
    }

    // 是否为「音乐型」播放器：决定灵动岛 / 歌词面板是否触发 lyrics_fetcher。
    // 浏览器、视频播放器（VLC/mpv 默认）等归为非音乐，避免对网页/视频拉歌词。
    // 白名单：明确的音乐应用 → true
    // 黑名单：浏览器 / 已知视频播放器 → false
    // 其它（未知）：保守视为非音乐，宁可不查也不要乱查
    function isMusicPlayer(player) {
        if (!player) return false;
        const id = getIdentity(player).toLowerCase();
        if (!id || id === "no media") return false;
        // 黑名单：浏览器 / 视频播放器
        if (id === "browser" || id === "firefox" || id === "edge"
            || id === "vlc" || id === "mpv"
            || id.includes("chrome") || id.includes("chromium")
            || id.includes("youtube") || id.includes("netflix")
            || id.includes("bilibili") || id.includes("video")) {
            return false;
        }
        // 白名单：常见音乐播放器
        if (id === "spotify"
            || id === "splayer"
            || id.includes("music") || id.includes("audio")
            || id.includes("cmus") || id.includes("audacious")
            || id.includes("rhythmbox") || id.includes("clementine")
            || id.includes("strawberry") || id.includes("elisa")
            || id.includes("lollypop") || id.includes("quod")
            || id.includes("deadbeef") || id.includes("tauon")
            || id.includes("mpd") || id.includes("ncspot")
            || id.includes("amberol") || id.includes("netease")
            || id.includes("qqmusic") || id.includes("yesplaymusic")) {
            return true;
        }
        return false;
    }
}
