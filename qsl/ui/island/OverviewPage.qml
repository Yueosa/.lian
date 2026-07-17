// OverviewPage — Hub Overview：左身份/时钟/天气入口 + 右日历
// 性能：oneshot hostname/uptime；无 Sysmon；切 Tab 随 Loader 销毁

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.data.state
import qs.data.service

Item {
    id: root

    property string hostname: "localhost"
    property string uptimeText: "—"

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarLetter: userName.length > 0
        ? userName.charAt(0).toUpperCase()
        : "?"

    readonly property string greetText: {
        const d = Time.rawDate
        const hr = d ? d.getHours() : 0
        if (hr < 5) return "夜深了"
        if (hr < 9) return "早安"
        if (hr < 12) return "上午好"
        if (hr < 14) return "中午好"
        if (hr < 18) return "下午好"
        if (hr < 22) return "晚上好"
        return "夜安"
    }

    function formatUptime(secs) {
        const s = Math.max(0, Math.floor(Number(secs) || 0))
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0)
            return "up " + d + "d " + h + "h"
        if (h > 0)
            return "up " + h + "h " + m + "m"
        return "up " + m + "m"
    }

    function applySysinfo(text) {
        const lines = String(text || "").trim().split("\n")
        if (lines.length >= 1 && lines[0].trim().length)
            hostname = lines[0].trim()
        if (lines.length >= 2)
            uptimeText = formatUptime(lines[1].trim())
    }

    Component.onCompleted: sysProc.running = true

    Process {
        id: sysProc
        command: [
            "sh", "-c",
            "printf '%s\\n' \"$(cat /etc/hostname 2>/dev/null)\" "
            + "\"$(cut -d. -f1 /proc/uptime 2>/dev/null)\""
        ]
        stdout: StdioCollector {
            id: sysOut
            onStreamFinished: root.applySysinfo(sysOut.text)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 20

        // ---- 左栏 ----
        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.fillWidth: false
            Layout.fillHeight: true
            spacing: 14

            // 身份卡（加大）
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 168
                radius: Size.rounding.lg
                color: Color.surfaceHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    Item {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 100
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Color.surfaceHighest
                            visible: avatarImg.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: root.avatarLetter
                                color: Color.primary
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.hero
                                font.bold: true
                            }
                        }

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: Size.island.avatarUrl
                            sourceSize: Qt.size(200, 200)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: false
                        }

                        Rectangle {
                            id: avatarMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: avatarImg
                            maskSource: avatarMask
                            visible: avatarImg.status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.userName
                            color: Color.textOnBackground
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.xl
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.hostname
                            color: Color.textMuted
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.md
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 6
                            Text {
                                text: "\uf303"
                                color: Color.primary
                                font.family: Size.fontMono
                                font.pixelSize: Size.fontSize.md
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Arch · " + root.uptimeText
                                color: Color.textMuted
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.sm
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // 大时钟（两行：问候 + 时间）
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: Size.rounding.lg
                color: Color.surfaceHigh

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.greetText
                        color: Color.primary
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(Time.rawDate, "HH:mm")
                        color: Color.textOnBackground
                        font.family: Size.fontMono
                        font.pixelSize: 52
                        font.weight: Font.Black
                    }
                }
            }

            // 天气轻量预览 → Weather Tab
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Size.rounding.lg
                color: Color.surfaceHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: Size.spacing.md

                    WeatherIcon {
                        sourceUrl: Weather.iconSource
                        pixelSize: 64
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: Weather.ready ? Weather.tempText : "--"
                            color: Color.textOnBackground
                            font.family: Size.fontMono
                            font.pixelSize: 40
                            font.weight: Font.Black
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Weather.ready
                                ? (Weather.weatherText + " · " + Weather.locationName)
                                : "天气加载中…"
                            color: Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.md
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: "\uf054"
                        color: Color.textMuted
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.lg
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.hubTabIndex = 3
                }

                Component.onCompleted: Weather.ensureDaemon()
            }
        }

        OverviewCalendar {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
