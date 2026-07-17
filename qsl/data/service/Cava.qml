pragma Singleton

// ============================================================
// 音频频谱 — Cava
// ============================================================
// cava-relay → $XDG_RUNTIME_DIR/qsl/cava.bin（30×u8）
// refCount>0 才跑；values 归一 0–1，约 30fps
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

    function acquire() {
        refCount += 1
    }

    function release() {
        refCount = Math.max(0, refCount - 1)
        if (refCount === 0)
            values = []
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

    Component.onCompleted: values = _zeroValues()

    // 中继进程
    Process {
        id: relayProc
        running: root.refCount > 0
        command: [root.relayBin]
        onRunningChanged: {
            if (!running && root.refCount === 0)
                root.values = root._zeroValues()
        }
    }

    // 长驻读 cava.bin → CSV（避免 FileView 二进制/每帧起进程）
    Process {
        id: readerProc
        running: root.refCount > 0
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
