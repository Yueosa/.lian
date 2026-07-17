pragma Singleton

// ============================================================
// 更新服务 — Updates
// ============================================================
// 后端：scripts/updatesctl → ~/.cache/qsl/updates.json
// 仅 detailActive 时 hydrate + 拉取；关页 release 清包列表
// 无 Timer / 无启动自检
// ============================================================
// 对外接口：
//   detailActive / setDetailActive(bool)
//   loading / ok
//   officialCount / aurCount / totalCount
//   officialPackages / aurPackages / flatRows
//   updatedAgo / errorAgo / lastAppliedCount / lastAppliedAgo
//   hydrate() / refresh() / release()
//   openUpgrade()   // kitty: tcr && paru|pacman -Syu
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string ctlPath: Quickshell.shellDir + "/scripts/updatesctl"
    readonly property string cachePath:
        Quickshell.env("HOME") + "/.cache/qsl/updates.json"

    property bool detailActive: false
    property bool loading: false

    property bool ok: true
    property int officialCount: 0
    property int aurCount: 0
    property int totalCount: 0
    property var officialPackages: []
    property var aurPackages: []
    property var flatRows: []
    property string updatedAgo: "从未"
    property string errorAgo: ""
    property int lastAppliedCount: 0
    property string lastAppliedAgo: ""

    function setDetailActive(active) {
        detailActive = !!active
        if (detailActive) {
            hydrate()
            refresh()
        } else {
            release()
        }
    }

    function hydrate() {
        cacheView.reload()
    }

    function refresh() {
        if (loading)
            return
        loading = true
        checkProc.running = true
    }

    function release() {
        // 关页清展示数组，减内存；计数/ago 留给下次 hydrate
        officialPackages = []
        aurPackages = []
        flatRows = []
        if (checkProc.running)
            checkProc.running = false
        loading = false
    }

    function openUpgrade() {
        // tcr（~/.local/bin）成功后再 Syu；失败则停
        const cmd = "export PATH=\"$HOME/.local/bin:$PATH\"; "
            + "tcr && (command -v paru >/dev/null && paru -Syu || sudo pacman -Syu); "
            + "echo; read -r -p \"按回车关闭…\" _"
        Quickshell.execDetached(["kitty", "-e", "bash", "-lc", cmd])
    }

    function rebuildFlatRows() {
        // AUR 置顶（通常更少）；官方仓在后
        const rows = []
        function pushSection(title, section, count, pkgs) {
            if (count <= 0)
                return
            rows.push({
                kind: "header",
                title: title,
                count: count,
                section: section
            })
            const list = pkgs || []
            for (let i = 0; i < list.length; i++) {
                const p = list[i]
                rows.push({
                    kind: "pkg",
                    name: p.name || String(p),
                    from: p.from || "",
                    to: p.to || "",
                    section: section
                })
            }
        }
        pushSection("AUR", "aur", aurCount, aurPackages)
        pushSection("官方仓库", "official", officialCount, officialPackages)
        flatRows = rows
    }

    function applyPayload(data) {
        if (!data || typeof data !== "object")
            return
        ok = !!data.ok
        officialCount = data.official || 0
        aurCount = data.aur || 0
        totalCount = data.total || (officialCount + aurCount)
        officialPackages = data.official_packages || []
        aurPackages = data.aur_packages || []
        updatedAgo = data.updated_ago || "从未"
        errorAgo = data.error_ago || ""
        lastAppliedCount = data.last_applied_count || 0
        lastAppliedAgo = data.last_applied_ago || ""
        rebuildFlatRows()
    }

    function applyJsonText(raw) {
        try {
            const t = (raw || "").trim()
            if (!t)
                return
            applyPayload(JSON.parse(t))
        } catch (e) {
            console.warn("Updates: parse failed", e)
        }
    }

    FileView {
        id: cacheView
        path: root.cachePath
        watchChanges: false
        onLoaded: {
            if (root.detailActive)
                root.applyJsonText(text())
        }
        onLoadFailed: {
            // 无缓存时等 check 结果即可
        }
    }

    Process {
        id: checkProc
        command: ["python3", root.ctlPath, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.detailActive)
                    return
                root.applyJsonText(this.text)
            }
        }
        onExited: root.loading = false
    }
}
