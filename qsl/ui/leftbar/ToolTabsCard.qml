// ToolTabsCard — 工具页芯片条（time 页头部拆出的容器卡）
// 组选中状态在 Leftbar.toolState（与下方三张卡共享），本卡只读写它
//
// 三个 chip 是写死的：时间 / 计算器 / 提醒。和 KeysTabsCard 的区别——那边吃
// Hotkeys.groups 的动态清单，要 Flickable 防溢出；工具集合不会热变化，摆个
// 静态 Row 就够，不值得为它上可滚动（第 10 轮「重复实现收编」的反面教训：
// 长得像但行为不一样的东西别硬抽）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

    // 指向 Leftbar.toolState（groupId）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    ColumnLayout {
        id: mainCol
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        spacing: Size.spacing.md

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "工具"
                color: Color.text
                font.pixelSize: Size.fontSize.titleMedium
                font.bold: true
            }
            Item { Layout.fillWidth: true }
        }

        Row {
            spacing: Size.spacing.xs

            QslChip {
                text: "时间"
                icon: "schedule"
                chipHeight: 32
                selected: root.sharedState.groupId === "time"
                onClicked: root.sharedState.groupId = "time"
            }
            QslChip {
                text: "计算器"
                icon: "calculate"
                chipHeight: 32
                selected: root.sharedState.groupId === "calc"
                onClicked: root.sharedState.groupId = "calc"
            }
            QslChip {
                text: "提醒"
                icon: "alarm"
                chipHeight: 32
                selected: root.sharedState.groupId === "remind"
                onClicked: root.sharedState.groupId = "remind"
            }
        }
    }
}
