// QslActionChip — 行内操作 pill（V 面板四页共用）
//
// 设计里的 .pill：小号、圆头、带强调色。行尾操作和行内确认都用它
//   [连接] [取消] [忘记] [配对] [断开] [⟳ 检查]
// 和 QslChip 的区别：QslChip 是侧栏 Tab 的选中态芯片（36px、无强调色），
// 这个是操作钮（24px、有 accent、有主/次强调）

import QtQuick
import qs.Components
import qs.data.state

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    // 强调色：破坏性操作传 Color.error
    property color accent: Color.primary
    // 主操作实底，次操作只在悬停时上底
    property bool filled: false
    property bool enabled: true
    property bool busy: false
    signal clicked()

    implicitHeight: 24
    implicitWidth: row.implicitWidth + Size.spacing.md
    radius: Size.rounding.full
    opacity: enabled ? 1 : 0.4
    // 主操作静息就带底色，次操作静息透明——两者的悬停/按下反馈由状态层统一
    // 叠在上面，所以这里只管"静息长什么样"
    color: root.filled
        ? Color.withAlpha(root.accent, root.enabled ? Color.state.selected : 0.12)
        : "transparent"
    Behavior on color { CAnim {} }

    QslStateLayer {
        source: ma
        active: root.enabled
        tint: root.accent
        accent: true
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Size.spacing.xs

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Size.fontIcon
            font.pixelSize: Size.iconSize.sm
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter

            // 装饰性/刷新动画，不走令牌（plan.md 白名单）
            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: root.busy
            }
        }
        Text {
            text: root.text
            font.pixelSize: Size.fontSize.labelSmall
            font.bold: root.filled
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
