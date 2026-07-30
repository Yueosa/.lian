// MaintainPage — 运行时体检 + 服务清单 + 动作
// 进页 / 刷新采一次；无常驻 Timer
// 性能：固定行数 ListView；Process 短命；关页销毁

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.data.state
import qs.data.service

Item {
    id: root

    property int qsRssKiB: 0
    property int cavaReaders: 0
    property bool relayUp: false
    property bool cavaUp: false
    property bool sysmondUp: false
    property bool weatherdUp: false
    property string statusMsg: ""
    property string confirmKind: "" // "" | clear | restart

    readonly property string cacheDir: {
        const home = Quickshell.env("HOME") || ""
        return home + "/.cache/qsl"
    }

    readonly property string qsRssText: qsRssKiB > 0
        ? (Math.round(qsRssKiB / 1024) + " MiB")
        : "—"

    readonly property string healthTone: {
        if (cavaReaders >= 2)
            return "bad"
        if (!sysmondUp || qsRssKiB > 600 * 1024)
            return "warn"
        return "ok"
    }

    // 固定清单：进程态来自 probe；QML 态直接绑服务
    readonly property var serviceRows: [
        {
            id: "cava",
            name: "Cava",
            role: "频谱",
            alive: relayUp || cavaUp || cavaReaders > 0,
            detail: "ref " + Cava.refCount
                + " · reader " + cavaReaders
                + (relayUp ? " · relay" : "")
                + (cavaUp ? " · cava" : "")
        },
        {
            id: "sysmon",
            name: "Sysmon",
            role: "监视",
            alive: sysmondUp,
            detail: Sysmon.summaryActive
                ? (Sysmon.detailActive ? "summary+detail" : "summary")
                : (Sysmon.detailActive ? "detail" : "idle")
        },
        {
            id: "weather",
            name: "Weather",
            role: "天气",
            alive: weatherdUp,
            detail: Weather.detailActive ? "detail" : "light"
        },
        {
            id: "network",
            name: "Network",
            role: "网络",
            alive: true,
            detail: Network.detailActive
                ? (Network.wifiScanning ? "detail · scan" : "detail")
                : (Network.wifiConnected ? "chip · up" : "chip")
        },
        {
            id: "bluetooth",
            name: "Bluetooth",
            role: "蓝牙",
            alive: Bluetooth.hasAdapter,
            detail: Bluetooth.detailActive
                ? (Bluetooth.discovering ? "detail · scan" : "detail")
                : (Bluetooth.enabled ? "on" : "off")
        },
        {
            id: "volume",
            name: "Volume",
            role: "声音",
            alive: true,
            detail: Volume.detailActive ? "detail" : "chip"
        }
    ]

    function refresh() {
        probeProc.running = true
    }

    function openPath(path) {
        if (!path)
            return
        Quickshell.execDetached(["kitty", "-e", "nvim", path])
    }

    function clearCache() {
        clearProc.running = true
    }

    function clearCavaOrphans() {
        Cava.cleanupOrphans()
        statusMsg = "已请求清理 cava 孤儿"
        orphanRefresh.restart()
    }

    Timer {
        id: orphanRefresh
        interval: 500
        repeat: false
        onTriggered: root.refresh()
    }

    function restartQs() {
        const wd = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        const xdg = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
        const dbus = Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""
        let cmd = "pkill -x qs; sleep 0.5; "
            + "export WAYLAND_DISPLAY=" + wd + "; "
            + "export XDG_RUNTIME_DIR=" + xdg + "; "
        if (dbus)
            cmd += "export DBUS_SESSION_BUS_ADDRESS='" + dbus + "'; "
        cmd += "MALLOC_CONF=background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000 "
            + "QSG_RENDER_LOOP=basic qs -d -n >/tmp/qsl_restart.log 2>&1 &"
        Quickshell.execDetached(["bash", "-lc", cmd])
    }

    function metricColor(ok, warn) {
        if (ok === false || warn)
            return Color.error
        return Color.primary
    }

    Component.onCompleted: refresh()

    Process {
        id: probeProc
        command: [
            "bash", "-lc",
            "rss=$(ps -o rss= -C qs 2>/dev/null | awk '{s+=$1} END{print s+0}'); "
            + "readers=$(ps -eo cmd | awk '/python3/ && /cava\\.bin/ && !/awk/ {n++} END{print n+0}'); "
            + "relay=$(pgrep -c -f '[c]ava-relay' 2>/dev/null || echo 0); "
            + "cava=$(pgrep -cx cava 2>/dev/null || echo 0); "
            + "sys=$(pgrep -cx sysmond 2>/dev/null || echo 0); "
            + "wx=$(pgrep -cx weatherd 2>/dev/null || echo 0); "
            + "echo \"$rss $readers $relay $cava $sys $wx\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                root.qsRssKiB = Number(p[0]) || 0
                root.cavaReaders = Number(p[1]) || 0
                root.relayUp = (Number(p[2]) || 0) > 0
                root.cavaUp = (Number(p[3]) || 0) > 0
                root.sysmondUp = (Number(p[4]) || 0) > 0
                root.weatherdUp = (Number(p[5]) || 0) > 0
            }
        }
    }

    Process {
        id: clearProc
        command: [
            "bash", "-lc",
            "rm -rf -- '" + root.cacheDir + "'/* 2>/dev/null; mkdir -p '" + root.cacheDir + "'; exit 0"
        ]
        onExited: {
            root.statusMsg = "缓存已清"
            root.confirmKind = ""
            root.refresh()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "维护"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: refreshMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "refresh"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Color.textMuted
                }
                MouseArea {
                    id: refreshMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }

        // ----- 体检条 -----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Size.rounding.md
            color: root.healthTone === "bad"
                ? Color.withAlpha(Color.error, 0.12)
                : (root.healthTone === "warn"
                    ? Color.withAlpha(Color.primary, 0.08)
                    : Color.withAlpha(Color.primary, 0.12))
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 0

                Repeater {
                    model: [
                        {
                            label: "RSS",
                            value: root.qsRssText,
                            warn: root.qsRssKiB > 600 * 1024
                        },
                        {
                            label: "cava rdr",
                            value: String(root.cavaReaders),
                            warn: root.cavaReaders >= 2
                        },
                        {
                            label: "sysmond",
                            value: root.sysmondUp ? "up" : "down",
                            warn: !root.sysmondUp
                        },
                        {
                            label: "weatherd",
                            value: root.weatherdUp ? "up" : "down",
                            warn: !root.weatherdUp
                        },
                        {
                            label: "relay",
                            value: root.relayUp ? "up" : "—",
                            warn: false
                        }
                    ]

                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        Rectangle {
                            visible: index > 0
                            width: 1
                            Layout.fillHeight: true
                            Layout.topMargin: 14
                            Layout.bottomMargin: 14
                            color: Color.outlineVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: index > 0 ? 12 : 0
                            spacing: 2
                            Text {
                                text: modelData.label
                                font.pixelSize: Size.fontSize.xsm
                                color: Color.textMuted
                            }
                            Text {
                                text: modelData.value
                                font.bold: true
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.md
                                color: modelData.warn ? Color.error : Color.primary
                            }
                        }
                    }
                }
            }
        }

        // ----- 服务清单（吃满中间） -----
        Text {
            text: "服务"
            font.bold: true
            font.pixelSize: Size.fontSize.sm
            color: Color.textMuted
            Layout.topMargin: 4
        }

        ListView {
            id: svcList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.serviceRows

            delegate: Rectangle {
                id: svcRow
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: 48
                radius: Size.rounding.md
                color: Color.withAlpha(Color.text, 0.04)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: Size.spacing.md

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: svcRow.modelData.alive ? Color.primary : Color.textMuted
                    }

                    Text {
                        text: svcRow.modelData.name
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.text
                        Layout.preferredWidth: 88
                    }

                    Text {
                        text: svcRow.modelData.role
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        Layout.preferredWidth: 40
                    }

                    Text {
                        Layout.fillWidth: true
                        text: svcRow.modelData.detail
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // ----- 动作（置底） -----
        Text {
            text: "动作"
            font.bold: true
            font.pixelSize: Size.fontSize.sm
            color: Color.textMuted
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            columns: 2
            rowSpacing: Size.spacing.sm
            columnSpacing: Size.spacing.sm

            Repeater {
                model: [
                    { id: "orphans", title: "清 cava 孤儿", sub: "reader / relay", icon: "mop", danger: false },
                    { id: "restart", title: "重启 qs", sub: "短暂中断", icon: "restart_alt", danger: true },
                    { id: "clear", title: "清缓存", sub: "~/.cache/qsl", icon: "delete_sweep", danger: true },
                    { id: "cache", title: "缓存目录", sub: "nvim", icon: "folder_open", danger: false },
                    { id: "log", title: "日志目录", sub: "by-id", icon: "description", danger: false },
                    { id: "shell", title: "shell 目录", sub: "qsl 源码", icon: "code", danger: false }
                ]

                delegate: Rectangle {
                    id: act
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Size.rounding.md
                    color: Color.surfaceHigh
                    border.width: Style.border.width
                    border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: Size.spacing.sm

                        Text {
                            text: act.modelData.icon
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.lg
                            color: act.modelData.danger ? Color.error : Color.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: act.modelData.title
                                font.bold: true
                                font.pixelSize: Size.fontSize.sm
                                color: Color.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: act.modelData.sub
                                font.pixelSize: Size.fontSize.xsm
                                color: Color.textMuted
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const id = act.modelData.id
                            if (id === "orphans") {
                                root.confirmKind = ""
                                root.clearCavaOrphans()
                            } else if (id === "restart") {
                                root.confirmKind = "restart"
                            } else if (id === "clear") {
                                root.confirmKind = "clear"
                            } else if (id === "cache") {
                                root.openPath(root.cacheDir)
                            } else if (id === "log") {
                                const xdg = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
                                root.openPath(xdg + "/quickshell/by-id")
                            } else if (id === "shell") {
                                root.openPath(Quickshell.shellDir)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.confirmKind !== ""
            implicitHeight: visible ? 44 : 0
            radius: Size.rounding.md
            color: Color.withAlpha(Color.error, 0.12)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: Size.spacing.sm
                Text {
                    Layout.fillWidth: true
                    text: root.confirmKind === "restart" ? "确认重启 qs？" : "确认清空缓存？"
                    color: Color.error
                    font.pixelSize: Size.fontSize.sm
                }
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 28
                    radius: Size.rounding.sm
                    color: Color.withAlpha(Color.text, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "取消"
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.confirmKind = ""
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 28
                    radius: Size.rounding.sm
                    color: Color.withAlpha(Color.error, 0.25)
                    Text {
                        anchors.centerIn: parent
                        text: "确认"
                        font.bold: true
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.error
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.confirmKind === "restart")
                                root.restartQs()
                            else if (root.confirmKind === "clear")
                                root.clearCache()
                        }
                    }
                }
            }
        }

        Text {
            visible: root.statusMsg !== ""
            Layout.fillWidth: true
            text: root.statusMsg
            color: Color.primary
            font.pixelSize: Size.fontSize.sm
        }
    }
}
