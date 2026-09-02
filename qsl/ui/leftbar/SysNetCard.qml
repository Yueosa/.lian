// SysNetCard — 网络（A2 版：从 SysResourcesCard 抽出的独立卡）
// 标题行 = iface + ↓↑ 速率；下面上下行双折线
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 两条曲线共用同一纵轴（按近期峰值自适应），否则各自归一化，
// 视觉上会把 1 K/s 画得和 10 M/s 一样高

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "网络"
                color: Color.text
                font.pixelSize: Size.fontSize.md
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (Sysmon.netIface.length > 0 ? Sysmon.netIface + " · " : "")
                    + "↓" + Sysmon.formatBytes(Sysmon.netDownBps)
                    + " ↑" + Sysmon.formatBytes(Sysmon.netUpBps)
                color: Color.textMuted
                font.pixelSize: Size.fontSize.xsm
                font.family: Size.fontMono
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            Sparkline {
                anchors.fill: parent
                values: Sysmon.netDownHistory
                overrideMax: Sysmon.netPeak
                lineColor: Color.primary
            }
            Sparkline {
                anchors.fill: parent
                values: Sysmon.netUpHistory
                overrideMax: Sysmon.netPeak
                lineColor: Color.tertiary
                fillOpacity: 0.10
                opacity: 0.7
            }
        }
    }
}
