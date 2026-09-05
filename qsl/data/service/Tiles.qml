pragma Singleton

// ============================================================
// X 磁贴清单与动作 — Tiles
// ============================================================
// asset/tiles.json：browser / run[] / svc[]（格式说明写在那个文件的 _doc 里）
// FileView watchChanges：改完存盘即生效，不用重启 qs
//
// 这一层只管「清单」和「点下去干什么」。服务的状态和启停在
// data/service/Systemd.qml，两边通过面板注入的 units 清单对接。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var run: []
    property var svc: []
    property var browser: ({ cmd: "", classes: [] })
    property bool ready: false
    property string error: ""

    // 服务区所有单元摊平（面板把它交给 Systemd 去查）
    readonly property var svcUnits: {
        const out = []
        const list = root.svc || []
        for (let i = 0; i < list.length; i++) {
            const u = list[i] && list[i].units
            const n = u ? u.length : 0
            if (typeof n !== "number" || n <= 0)
                continue
            for (let j = 0; j < n; j++) {
                if (out.indexOf(u[j]) < 0)
                    out.push(u[j])
            }
        }
        return out
    }

    readonly property string jsonPath: {
        const base = Qt.resolvedUrl("../../asset/tiles.json")
        return String(base).replace("file://", "")
    }

    function reload() {
        fileView.reload()
    }

    // ---- 执行区：点一下 ----
    function activate(tile) {
        if (!tile)
            return
        if (tile.url) {
            openUrl(String(tile.url))
            return
        }
        if (Array.isArray(tile.exec) && tile.exec.length > 0) {
            Quickshell.execDetached(tile.exec)
            return
        }
        error = "磁贴 " + (tile.id || "?") + " 既没有 url 也没有 exec"
    }

    // 一律在**当前工作区开新窗口**。
    //
    // chrome 是单实例的：`chrome <url>` 只会把地址交给已经在跑的那个进程，
    // 它开在「最后活跃的那扇窗」里——那扇窗多半在别的工作区。所以不找已有
    // 窗口、不加 --new-window 都不行。Hyprland 把新窗放在当前工作区。
    function openUrl(url) {
        const cmd = String((root.browser && root.browser.cmd) || "")
        if (!cmd.length) {
            error = "tiles.json 里没写 browser.cmd"
            return
        }
        Quickshell.execDetached([cmd].concat(root._newWindowArgs(), [url]))
    }

    function _newWindowArgs() {
        const a = root.browser && root.browser.newWindow
        if (a && a.length !== undefined) {
            const out = []
            for (let i = 0; i < a.length; i++)
                out.push(a[i])
            if (out.length > 0)
                return out
        }
        return ["--new-window"]
    }

    // ---- 读盘 ----
    function applyText(raw) {
        try {
            const t = (raw || "").trim()
            if (!t) {
                run = []
                svc = []
                ready = false
                error = "空文件"
                return
            }
            const data = JSON.parse(t)
            run = Array.isArray(data.run) ? data.run : []
            svc = Array.isArray(data.svc) ? data.svc : []
            browser = data.browser || ({ cmd: "", classes: [] })
            ready = true
            error = ""
        } catch (e) {
            run = []
            svc = []
            ready = false
            error = String(e)
            console.warn("Tiles: parse failed", e)
        }
    }

    FileView {
        id: fileView
        path: root.jsonPath
        watchChanges: true
        onLoaded: root.applyText(text())
        onFileChanged: reload()
        onLoadFailed: {
            root.run = []
            root.svc = []
            root.ready = false
            root.error = "无法读取 tiles.json"
        }
    }

    Component.onCompleted: reload()
}
