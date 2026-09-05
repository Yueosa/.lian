// SysDiskCard — 磁盘 / Swap 两行条（系统页容器卡）
// 电池/Uptime 已移往 island overview，本卡只剩存储
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    anchors.fill: parent
    implicitHeight: col.implicitHeight + 32   // 上下各 16 留白

    ColumnLayout {
        id: col
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm
            Text {
                text: "磁盘"
                font.pixelSize: Size.fontSize.labelMedium
                color: Color.text
                Layout.preferredWidth: 44
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Color.withAlpha(Color.text, 0.08)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Sysmon.diskPercent / 100))
                    height: parent.height
                    radius: 3
                    color: Color.secondary
                }
            }
            Text {
                text: Math.round(Sysmon.diskPercent) + "% · "
                    + Math.round(Sysmon.diskUsedGB) + "/"
                    + Math.round(Sysmon.diskTotalGB) + "G"
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.labelSmall
                color: Color.textMuted
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm
            Text {
                text: "Swap"
                font.pixelSize: Size.fontSize.labelMedium
                color: Color.text
                Layout.preferredWidth: 44
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Color.withAlpha(Color.text, 0.08)
                Rectangle {
                    width: parent.width * (Sysmon.swapTotalGB > 0
                        ? Math.max(0, Math.min(1, Sysmon.swapUsedGB / Sysmon.swapTotalGB)) : 0)
                    height: parent.height
                    radius: 3
                    color: Color.primary
                }
            }
            Text {
                text: Sysmon.swapUsedGB.toFixed(1) + "/" + Sysmon.swapTotalGB.toFixed(0) + "G"
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.labelSmall
                color: Color.textMuted
            }
        }
    }
}
