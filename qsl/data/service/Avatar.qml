pragma Singleton

// ============================================================
// 头像 — Avatar
// ============================================================
// 远程原图在 Size.island.avatarUrl（QQ）。Image 直接吃 http 会不定时
// Connection closed，Overview / powerbar 一起空白。
//
// 这里只对外暴露 file://：有盘上缓存就先画，后台再刷新。
// 缓存 ~/.cache/qsl/avatar.jpg；六小时内不重下。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import qs.data.state

Singleton {
    id: root

    readonly property string remoteUrl: Size.island.avatarUrl
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qsl/avatar.jpg"

    // 给 Image.source 用。空串 = 还没有可画的文件，UI 走字母回退
    property string source: ""

    property bool _armed: false

    function ensure() {
        if (root._armed)
            return
        root._armed = true
        probeProc.running = true
    }

    function _show(forceReload) {
        const url = "file://" + root.cachePath
        if (forceReload) {
            root.source = ""
            Qt.callLater(() => { root.source = url })
            return
        }
        if (root.source !== url)
            root.source = url
    }

    Process {
        id: probeProc
        command: ["test", "-s", root.cachePath]
        onExited: (code) => {
            if (code === 0)
                root._show(false)
            fetchProc.running = true
        }
    }

    Process {
        id: fetchProc
        command: [
            "bash", "-lc",
            "out=\"$HOME/.cache/qsl/avatar.jpg\"; "
            + "url='" + root.remoteUrl.replace(/'/g, "'\\''") + "'; "
            + "mkdir -p \"$HOME/.cache/qsl\"; "
            + "if [ -s \"$out\" ]; then "
            + "  age=$(( $(date +%s) - $(stat -c %Y \"$out\") )); "
            + "  if [ \"$age\" -lt 21600 ]; then exit 3; fi; "
            + "fi; "
            + "tmp=\"$out.tmp\"; "
            + "curl -fsSL --connect-timeout 5 --max-time 20 -o \"$tmp\" \"$url\" || exit 1; "
            + "sz=$(wc -c < \"$tmp\"); "
            + "if [ \"$sz\" -lt 200 ]; then rm -f \"$tmp\"; exit 1; fi; "
            + "if [ -s \"$out\" ] && cmp -s \"$tmp\" \"$out\"; then rm -f \"$tmp\"; exit 3; fi; "
            + "mv -f \"$tmp\" \"$out\""
        ]
        onExited: (code) => {
            if (code === 0)
                root._show(true)
        }
    }

    Component.onCompleted: root.ensure()
}
