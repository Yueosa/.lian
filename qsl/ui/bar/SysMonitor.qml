// SysMonitor — 栏上硬件摘要
// 默认只显示 RAM；hover 展开 CPU% + GPU%
// 性能：复用 Sysmon 摘要 watch，无自建 Timer/Process

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.data.service

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse

    implicitHeight: 36
    implicitWidth: isHovered
        ? (contentLayout.implicitWidth + 24)
        : (ramGroup.implicitWidth + 24)

    Behavior on implicitWidth {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
        Sysmon.setSummaryActive(true)
        Sysmon.ensureDaemon()
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: contentLayout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        spacing: Size.spacing.md
        layoutDirection: Qt.RightToLeft

        // RAM 常驻（RightToLeft 下视觉仍在左侧）
        RowLayout {
            id: ramGroup
            spacing: 4
            Text {
                text: "memory"
                color: Color.secondary
                font.family: Size.fontIcon
                font.pixelSize: Size.fontSize.md
            }
            Text {
                text: Sysmon.ready
                    ? (Sysmon.ramUsedGB.toFixed(1) + "G")
                    : "—G"
                color: Color.textOnBackground
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.sm
            }
        }

        RowLayout {
            spacing: 4
            visible: opacity > 0
            opacity: root.isHovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Text {
                text: "speed"
                color: Color.primary
                font.family: Size.fontIcon
                font.pixelSize: Size.fontSize.md
            }
            Text {
                text: Math.round(Sysmon.cpuPercent) + "%"
                color: Color.textOnBackground
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.sm
            }
        }

        RowLayout {
            spacing: 4
            visible: Sysmon.gpuAvailable && opacity > 0
            opacity: root.isHovered && Sysmon.gpuAvailable ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // 与 SystemPage 一致：Outlined 无 graphics_card 字形
            Text {
                text: "developer_board"
                color: Color.tertiary
                font.family: Size.fontIcon
                font.pixelSize: Size.fontSize.md
            }
            Text {
                text: Math.round(Sysmon.gpuPercent) + "%"
                color: Color.textOnBackground
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.sm
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "sidebar", "open", "sys"])
    }
}
