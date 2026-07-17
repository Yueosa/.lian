pragma Singleton

// ============================================================
// 歌词服务 — Lyrics
// ============================================================
// lyrics-fetch CLI → lines[{time,text}]；页面驱动 fetch / syncPosition
// 同曲缓存；detailActive 仅控制轮询是否由页面开
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string fetchBin: Quickshell.shellDir + "/backend/lyrics/build/lyrics-fetch"

    property bool detailActive: false
    property int detailRef: 0
    property bool loading: false
    property var lines: []
    property int currentIndex: 0
    property string loadedKey: ""

    readonly property string currentText: {
        if (!lines || lines.length === 0)
            return ""
        const i = Math.max(0, Math.min(currentIndex, lines.length - 1))
        return String(lines[i].text || "")
    }

    function acquire() {
        detailRef += 1
        detailActive = true
    }

    function release() {
        detailRef = Math.max(0, detailRef - 1)
        detailActive = detailRef > 0
        if (!detailActive)
            loading = false
    }

    function setDetailActive(active) {
        if (active) {
            if (detailRef === 0)
                acquire()
        } else {
            detailRef = 0
            detailActive = false
            loading = false
        }
    }

    function clear() {
        lines = []
        currentIndex = 0
        loadedKey = ""
        loading = false
    }

    function trackKey(title, artist) {
        return String(title || "") + "\x1f" + String(artist || "")
    }

    function fetch(title, artist, playerName, mediaUrl) {
        const t = String(title || "").trim()
        const a = String(artist || "").trim()
        if (!t.length) {
            lines = [{ time: 0, text: "暂无歌词" }]
            currentIndex = 0
            loadedKey = ""
            loading = false
            return
        }
        const key = trackKey(t, a)
        if (key === loadedKey && lines.length > 0)
            return
        loading = true
        loadedKey = key
        fetchProc.command = [
            root.fetchBin,
            t,
            a,
            String(playerName || ""),
            String(mediaUrl || "")
        ]
        fetchProc.running = false
        fetchProc.running = true
    }

    function setPlaceholder(text) {
        lines = [{ time: 0, text: String(text || "") }]
        currentIndex = 0
        loadedKey = ""
        loading = false
    }

    // position：秒（部分播放器给微秒）
    function syncPosition(positionSec) {
        if (!lines || lines.length === 0)
            return
        let pos = Number(positionSec) || 0
        if (pos > 100000)
            pos = pos / 1000000
        // 略提前半秒切行，手感更贴拍
        pos += 0.5
        let idx = 0
        for (let i = 0; i < lines.length; i++) {
            if ((Number(lines[i].time) || 0) <= pos)
                idx = i
            else
                break
        }
        if (idx !== currentIndex)
            currentIndex = idx
    }

    function applyJson(raw) {
        try {
            const parsed = JSON.parse(String(raw || "").trim())
            if (!Array.isArray(parsed) || parsed.length === 0) {
                lines = [{ time: 0, text: "暂无歌词" }]
            } else {
                const out = []
                for (let i = 0; i < parsed.length; i++) {
                    out.push({
                        time: Number(parsed[i].time) || 0,
                        text: String(parsed[i].text || "")
                    })
                }
                lines = out
            }
            currentIndex = 0
        } catch (e) {
            console.warn("Lyrics: parse failed", e)
            lines = [{ time: 0, text: "歌词错误" }]
            currentIndex = 0
        }
        loading = false
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: root.applyJson(text)
        }
        onExited: (code) => {
            if (code !== 0 && root.loading) {
                root.lines = [{ time: 0, text: "暂无歌词" }]
                root.currentIndex = 0
                root.loading = false
            }
        }
    }
}
