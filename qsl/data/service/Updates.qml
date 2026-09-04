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
//   officialPackages / aurPackages / aurRows / officialRows
//   updatedAgo / errorAgo / lastAppliedCount / lastAppliedAgo
//   hydrate() / refresh() / release()
//   openUpgrade()   // kitty: tcr && paru|pacman -Syu
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import "rowsync.js" as RowSync

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
    // ---- 稳定行模型：让新包滑出来，而不是硬冒出来 ----
    //
    // 旧写法是一个扁平 JS 数组（flatRows），每次 applyPayload 整体重算，
    // ListView 只能整体重建，add/displaced 过渡播不了（这就是「updates 的包
    // 列表是突然出现的，不是滑出来的」）。见 rowsync.js。
    //
    // 包对象是每次重算新建的字面量，所以按包名比对而不是按身份
    ListModel {
        id: _aurModel
        dynamicRoles: true
    }

    ListModel {
        id: _officialModel
        dynamicRoles: true
    }

    readonly property var aurRows: _aurModel
    readonly property var officialRows: _officialModel
    // 空串 = 从未检查过（口径见 _ago）
    property string updatedAgo: ""
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
        syncRows()
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

    function syncRows() {
        const byName = function (p) { return p ? p.name : "" }
        RowSync.sync(_aurModel, aurPackages || [], "pkg", byName)
        RowSync.sync(_officialModel, officialPackages || [], "pkg", byName)
    }

    // 与 updatesctl 的 humanize_ago 同口径；ts<=0（没发生过）返回空串，
    // 让上层自己决定是显示「从未」还是整条隐藏
    function _ago(ts) {
        const t = Number(ts) || 0
        if (t <= 0)
            return ""
        const delta = Math.max(0, Math.floor(Date.now() / 1000) - t)
        if (delta < 60)
            return delta + " 秒前"
        if (delta < 3600)
            return Math.floor(delta / 60) + " 分钟前"
        if (delta < 86400)
            return Math.floor(delta / 3600) + " 小时前"
        return Math.floor(delta / 86400) + " 天前"
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
        // 人话时间字符串只在 updatesctl 的 stdout 里算好；直接读缓存文件
        // （hydrate）拿到的只有 *_at 时间戳，所以这里得自己算，
        // 否则明明有数据也会显示「从未检查」
        updatedAgo = data.updated_ago || _ago(data.updated_at)
        errorAgo = data.error_ago || _ago(data.last_error_at)
        lastAppliedCount = data.last_applied_count || 0
        lastAppliedAgo = data.last_applied_ago || _ago(data.last_applied_at)
        syncRows()
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
