// ReminderContent — 一级岛「提醒」形态的内容（qsl.md M2）
//
// 显示常驻提醒队列的头一条：alarm 图标 + 标题 + 计划时间 + 剩余条数角标。
// 整个岛体可点关闭——MouseArea 挂在 IslandShell 的 Loader 之上（同 notif
// toast 的做法，不依赖本文件内 MouseArea）；点掉头一条自动露出下一条，
// 全点掉岛回落原形态。
//
// 为什么不做成 5s toast：提醒是用户自己约的时间，错过一次就是错过，
// 必须手动确认。不受 DnD 影响——这条通路根本不经过 Notification。

import QtQuick
import qs.data.state

Item {
    id: root

    readonly property var item: Island.reminderCount > 0
        ? Island.reminders.get(0) : null

    Row {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: Size.spacing.md

        // 图标：实心 alarm（FILL 轴，同 TodoTabsCard 星标的用法）
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "alarm"
            font.family: Size.fontIcon
            font.pixelSize: Size.iconSize.xxl
            font.variableAxes: ({ "opsz": Size.iconSize.xxl, "FILL": 1 })
            color: Color.primary
        }

        // 标题
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 26 - Size.spacing.md - rightCol.width - Size.spacing.md
            spacing: 2

            Text {
                width: parent.width
                text: root.item ? (root.item.title || "提醒") : ""
                color: Color.text
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodyMedium
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.item ? "点击关闭" : ""
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelSmall
            }
        }

        // 计划时间 + 剩余条数
        Column {
            id: rightCol
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                anchors.right: parent.right
                text: (root.item && root.item.mode === "daily" ? "每天 " : "")
                    + (root.item ? root.item.at : "")
                color: Color.primary
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.bodyMedium
            }

            Text {
                anchors.right: parent.right
                visible: Island.reminderCount > 1
                text: "还有 " + (Island.reminderCount - 1) + " 条"
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.labelSmall
            }
        }
    }
}
