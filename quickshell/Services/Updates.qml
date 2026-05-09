pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string fetchScriptPath: Qt.resolvedUrl("../scripts/updates_fetch.sh").toString().replace("file://", "")
    readonly property string readScriptPath: Qt.resolvedUrl("../scripts/updates_read.py").toString().replace("file://", "")

    property int officialCount: 0
    property int aurCount: 0
    property int totalCount: 0
    property var officialPackages: []
    property var aurPackages: []
    property string updatedAgo: "从未"
    property string errorAgo: ""
    property bool ok: true

    function refresh() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["bash", fetchScriptPath]
        onExited: readProc.running = true
    }

    Process {
        id: readProc
        command: ["python3", readScriptPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const text = line.trim();
                if (!text)
                    return;
                try {
                    const data = JSON.parse(text);
                    root.officialCount = data.official || 0;
                    root.aurCount = data.aur || 0;
                    root.totalCount = data.total || 0;
                    root.officialPackages = data.official_packages || [];
                    root.aurPackages = data.aur_packages || [];
                    root.updatedAgo = data.updated_ago || "从未";
                    root.errorAgo = data.error_ago || "";
                    root.ok = !!data.ok;
                } catch (e) {
                    console.log("Updates parse failed:", e);
                }
            }
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
