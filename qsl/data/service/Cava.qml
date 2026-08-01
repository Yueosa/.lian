pragma Singleton

// ============================================================
// 音频频谱 — Cava
// ============================================================
// cava-relay → $XDG_RUNTIME_DIR/qsl/cava.bin（30×u8）
// refCount>0 才跑；values 归一 0–1，约 30fps
//
// 防泄漏：启动 / 首次 acquire / release→0 清孤儿；清理完成后再拉起 Process，
// 避免 pkill 误杀刚 spawn 的实例。
// reader cmdline 含 ` / 'qsl' / 'cava.bin'`（非字面量 qsl/cava.bin）。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string relayBin: Quickshell.shellDir + "/backend/cava/build/cava-relay"
    readonly property string binPath: {
        const xdg = Quickshell.env("XDG_RUNTIME_DIR")
        const base = (xdg && xdg.length > 0) ? xdg : "/tmp"
        return base + "/qsl/cava.bin"
    }

    property int refCount: 0
    property var values: []
    property bool active: refCount > 0
    property bool _pendingStart: false
    // 清理完成前不拉起子进程
    property bool _procsArmed: false

    // 匹配 python reader / relay / cava 配置的 cava；[q]/[c] 防自匹配 pkill 脚本
    readonly property string _orphanCmd:
        "pkill -f \"/ '[q]sl' / 'cava.bin'\" 2>/dev/null || true; "
        + "pkill -f '[c]ava-relay' 2>/dev/null || true; "
        + "pkill -f '[q]sl_cava.conf' 2>/dev/null || true; "
        + "exit 0"

    // 计数与进程启停解耦：refCount 无条件增减，_procsArmed 只作「孤儿已清干净」的闸门。
    // 旧写法在 refCount===0 分支不加计数、改由 _armAfterCleanup 强行置 1，
    // 清理窗口期内的并发 acquire 会被吞掉，计数与实际占用方数量对不上。
    function acquire() {
        refCount += 1
        if (refCount === 1) {
            _pendingStart = true
            _runOrphanCleanup()
        }
    }

    function release() {
        if (refCount === 0)
            return
        refCount -= 1
        if (refCount === 0) {
            _procsArmed = false
            _pendingStart = false
            values = _zeroValues()
            // 停 Process 后仍清一次，防热重载残留
            _runOrphanCleanup()
        }
    }

    // 仅清孤儿，不 arm（维护页用）
    function cleanupOrphans() {
        _pendingStart = false
        _runOrphanCleanup()
    }

    function _runOrphanCleanup() {
        if (orphanCleanup.running) {
            // 排队：当前清理结束后若仍需 start 会走 onExited
            return
        }
        orphanCleanup.running = true
    }

    function _zeroValues() {
        const arr = []
        for (let i = 0; i < 30; i++)
            arr.push(0)
        return arr
    }

    function _applyRawCsv(line) {
        const parts = String(line || "").trim().split(",")
        if (parts.length < 30)
            return
        const arr = []
        for (let i = 0; i < 30; i++) {
            const v = Number(parts[i]) || 0
            arr.push(Math.max(0, Math.min(1, v / 255)))
        }
        values = arr
    }

    // 清理期间占用方可能已全部撤走，此时不得再拉起进程
    function _armAfterCleanup() {
        if (!root._pendingStart)
            return
        root._pendingStart = false
        if (root.refCount > 0)
            root._procsArmed = true
    }

    Component.onCompleted: {
        values = _zeroValues()
        orphanCleanup.running = true
    }

    Process {
        id: orphanCleanup
        command: ["bash", "-lc", root._orphanCmd]
        onExited: root._armAfterCleanup()
    }

    Process {
        id: relayProc
        running: root._procsArmed && root.refCount > 0
        command: [root.relayBin]
        onRunningChanged: {
            if (!running && root.refCount === 0)
                root.values = root._zeroValues()
        }
    }

    Process {
        id: readerProc
        running: root._procsArmed && root.refCount > 0
        command: [
            "python3", "-u", "-c",
            "import time, pathlib, os\n"
            + "p = pathlib.Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / 'qsl' / 'cava.bin'\n"
            + "while True:\n"
            + "    try:\n"
            + "        d = p.read_bytes()\n"
            + "        if len(d) >= 30:\n"
            + "            print(','.join(str(b) for b in d[:30]), flush=True)\n"
            + "    except Exception:\n"
            + "        pass\n"
            + "    time.sleep(0.033)\n"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root.refCount > 0)
                    root._applyRawCsv(data)
            }
        }
        onRunningChanged: {
            if (!running)
                root.values = root._zeroValues()
        }
    }
}
