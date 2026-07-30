pragma Singleton

// ============================================================
// 音频频谱 — Cava
// ============================================================
// cava-relay → $XDG_RUNTIME_DIR/qsl/cava.bin（30×u8）
// refCount>0 才跑；values 归一 0–1，约 30fps
//
// 防泄漏：启动 / 首次 acquire 前清孤儿；清理完成后再拉起 Process，
// 避免 pkill 误杀刚 spawn 的实例
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

    function acquire() {
        if (refCount > 0) {
            refCount += 1
            return
        }
        // 先清孤儿，再 arm 进程
        _pendingStart = true
        orphanCleanup.running = true
    }

    function release() {
        refCount = Math.max(0, refCount - 1)
        if (refCount === 0) {
            _procsArmed = false
            _pendingStart = false
            values = []
        }
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

    function _armAfterCleanup() {
        if (root._pendingStart) {
            root._pendingStart = false
            root._procsArmed = true
            root.refCount = Math.max(1, root.refCount)
        }
    }

    Component.onCompleted: {
        values = _zeroValues()
        orphanCleanup.running = true
    }

    Process {
        id: orphanCleanup
        command: [
            "bash", "-lc",
            "pkill -f '[q]sl/cava.bin' 2>/dev/null || true; "
            + "pkill -f '[q]sl/backend/cava/build/cava-relay' 2>/dev/null || true; "
            + "pkill -f '[.]config/quickshell/backend/cava/build/cava-relay' 2>/dev/null || true; "
            + "pkill -f '[q]sl_cava.conf' 2>/dev/null || true; "
            + "exit 0"
        ]
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
