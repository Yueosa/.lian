// SysMonitor — 栏上硬件摘要
// 收起：RAM 数值 + 内存趋势线；hover 展开：RAM + CPU% + GPU% 数值，趋势线让位
// 性能：复用 Sysmon 摘要 watch，无自建 Timer/Process
//       唯一一条 Sparkline 跟摘要档 3s 一次的采样重绘，常驻开销约等于一张 30×14 的小贴图

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse
    // 悬停意图：进入即锁存展开，由 RightBar 完全离开 1s 后统一回收（见 Bar.qml）
    property bool expanded: false

    onIsHoveredChanged: {
        if (isHovered)
            expanded = true
    }

    // 收起动画期间内容比根宽，不裁会画到栏上
    clip: true

    implicitHeight: 36
    implicitWidth: expanded
        ? (contentLayout.implicitWidth + 24)
        : (ramGroup.implicitWidth + 24)

    Behavior on implicitWidth {
        Anim { type: Anim.SpatialFast }
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
                font.pixelSize: Size.iconSize.md
            }
            Text {
                text: Sysmon.ready
                    ? (Sysmon.ramUsedGB.toFixed(1) + "G")
                    : "—G"
                color: Color.backgroundText
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.labelMedium
            }
            // 只在收起时画：曲线是余光扫一眼的趋势，
            // hover 展开是为了读准确数字，两者挤在一起反而都看不清
            Sparkline {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                visible: !root.expanded && Sysmon.memHistory.length > 1
                values: Sysmon.memHistory
                maxValue: 100
                lineColor: Color.secondary
                lineWidth: 1.2
                // 栏上只有 14px 高，内存又长期平稳，带填充会糊成一个方块
                fillArea: false
            }
        }

        RowLayout {
            spacing: 4
            visible: opacity > 0
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effects } }

            Text {
                text: "speed"
                color: Color.primary
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.md
            }
            Text {
                text: Math.round(Sysmon.cpuPercent) + "%"
                color: Color.backgroundText
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.labelMedium
            }
        }

        RowLayout {
            spacing: 4
            visible: Sysmon.gpuAvailable && opacity > 0
            opacity: root.expanded && Sysmon.gpuAvailable ? 1 : 0
            Behavior on opacity { Anim { type: Anim.Effects } }

            // 与 SystemPage 一致：Outlined 无 graphics_card 字形
            Text {
                text: "developer_board"
                color: Color.tertiary
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.md
            }
            Text {
                text: Math.round(Sysmon.gpuPercent) + "%"
                color: Color.backgroundText
                font.family: Size.fontMono
                font.bold: true
                font.pixelSize: Size.fontSize.labelMedium
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
