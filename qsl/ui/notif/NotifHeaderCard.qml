// NotifHeaderCard — 标题 / 返回 / DND / 清空（原工具条；N 页两容器之一）
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: headerRow.implicitHeight + Size.spacing.lg * 2

    // 指向 NotifCenter.notifState（currentApp / clearing / 分组聚合）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    RowLayout {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Size.spacing.lg
        anchors.rightMargin: Size.spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Size.spacing.sm

        // 返回：仅在应用页显示，占位宽度随之收掉
        Rectangle {
            Layout.preferredWidth: root.sharedState.currentApp === "" ? 0 : 32
            Layout.preferredHeight: 32
            visible: Layout.preferredWidth > 0
            radius: Size.rounding.full
            color: backMa.containsMouse
                ? Color.withAlpha(Color.primary, 0.18)
                : "transparent"

            Behavior on Layout.preferredWidth {
                Anim { type: Anim.SpatialFast }
            }

            Text {
                anchors.centerIn: parent
                text: "\uf060"
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.md
                color: Color.text
            }
            MouseArea {
                id: backMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sharedState.backToApps()
            }
        }

        Text {
            text: root.sharedState.currentApp === "" ? "通知中心" : root.sharedState.currentAppName
            color: Color.text
            font.pixelSize: Size.fontSize.lg
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // 免打扰
        Rectangle {
            width: 32; height: 32
            radius: Size.rounding.full
            color: dndMa.containsMouse
                ? Color.withAlpha(Color.primary, 0.18)
                : "transparent"

            Text {
                anchors.centerIn: parent
                text: Notification.dndEnabled ? "\uf1f6" : "\uf0f3"
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.md
                color: Notification.dndEnabled ? Color.secondary : Color.text
            }
            MouseArea {
                id: dndMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notification.toggleDnd()
            }
        }

        // 清空
        Rectangle {
            width: 32; height: 32
            radius: Size.rounding.full
            color: clearMa.containsMouse
                ? Color.withAlpha(Color.error, 0.18)
                : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\uf1f8"
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.md
                color: Notification.hasNotifications ? Color.error : Color.textMuted
                opacity: Notification.hasNotifications ? 1 : 0.4
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: Notification.hasNotifications && !root.sharedState.clearing
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.sharedState.clearScoped()
            }
        }
        // 关窗：Esc / 点外侧（RailPage 内建，无 X）
    }
}
