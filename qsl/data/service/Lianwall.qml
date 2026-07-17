pragma Singleton

// ============================================================
// Lianwall — 壁纸引擎 CLI 封装（仅 Wallpaper Hub 页）
// detailActive 期间才跑 status/space/subscribe；关闭清空 items
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string spaceScript:
        Quickshell.shellDir + "/scripts/lianwall_space.py"

    property bool detailActive: false
    property bool loading: false
    property string error: ""

    property string mode: "Image"
    property string currentPath: ""
    property string currentFilename: ""
    property string engine: ""
    property int availableCount: 0
    property int totalCount: 0
    property int lockedCount: 0

    property var items: []

    readonly property bool isVideoMode: mode === "Video" || mode === "video"
    readonly property string modeLabel: isVideoMode ? "视频" : "图片"
    readonly property string modeIcon: isVideoMode ? "\uf008" : "\uf03e"

    function setDetailActive(active) {
        detailActive = !!active
        if (detailActive) {
            refresh()
        } else {
            items = []
            loading = false
            error = ""
            subProc.running = false
        }
    }

    function refresh() {
        if (!detailActive)
            return
        loading = true
        error = ""
        // 强制重启（避免 running 已 true 不触发）
        statusProc.running = false
        spaceProc.running = false
        statusProc.running = true
        spaceProc.running = true
    }

    function _runAction(args) {
        actionProc.running = false
        actionProc.command = args
        actionProc.running = true
        refreshDelay.interval = 120
        refreshDelay.restart()
    }

    function next() { _runAction(["lianwall", "next"]) }
    function previous() { _runAction(["lianwall", "prev"]) }
    function switchMode() { _runAction(["lianwall", "switch"]) }

    function setWallpaper(path) {
        const p = String(path || "")
        if (!p.length)
            return
        _runAction(["lianwall", "set", p])
    }

    function openGui() {
        Quickshell.execDetached(["lianwall-gui"])
    }

    function applyStatus(raw) {
        try {
            const d = JSON.parse(String(raw || "").trim() || "{}")
            mode = String(d.mode || "Image")
            currentPath = String(d.current || "")
            currentFilename = String(d.current_filename || "")
            engine = String(d.engine || "")
            availableCount = Number(d.available_count) || 0
            totalCount = Number(d.total_wallpapers) || 0
            lockedCount = Number(d.locked_count) || 0
        } catch (e) {
            error = "status 解析失败"
        }
    }

    function applySpace(raw) {
        try {
            const d = JSON.parse(String(raw || "").trim() || "{}")
            if (d.error)
                error = String(d.error)
            const list = Array.isArray(d.items) ? d.items : []
            const next = []
            for (let i = 0; i < list.length; i++) {
                const it = list[i] || {}
                next.push({
                    path: String(it.path || ""),
                    filename: String(it.filename || ""),
                    thumb: String(it.thumb || ""),
                    thumb_orig: !!it.thumb_orig,
                    is_current: !!it.is_current,
                    locked: !!it.locked,
                    is_video: !!it.is_video
                })
            }
            items = next
            if (d.mode)
                mode = String(d.mode)
        } catch (e) {
            error = "space 解析失败"
            items = []
        }
    }

    Process {
        id: statusProc
        command: ["lianwall", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(this.text)
        }
        onExited: {
            if (!spaceProc.running)
                root.loading = false
        }
    }

    Process {
        id: spaceProc
        command: ["python3", root.spaceScript]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applySpace(this.text)
                root.loading = false
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.detailActive)
                root.error = "space 拉取失败"
        }
    }

    Process {
        id: actionProc
        command: ["true"]
        stdout: StdioCollector { onStreamFinished: {} }
        onExited: {
            if (root.detailActive) {
                refreshDelay.interval = 180
                refreshDelay.restart()
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 180
        repeat: false
        onTriggered: {
            if (root.detailActive)
                root.refresh()
        }
    }

    Process {
        id: subProc
        command: ["lianwall", "subscribe", "--json", "wallpaper", "status", "space"]
        running: root.detailActive
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: {
                if (root.detailActive) {
                    refreshDelay.interval = 100
                    refreshDelay.restart()
                }
            }
        }
    }
}
