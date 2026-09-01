// QslIconButton — 圆角图标按钮（学 clavis 右栏 ToolButton 40 圆）
// icon 用 Material Symbols 名称或码点；busy 时可转

import QtQuick
import qs.data.state

Rectangle {
    id: root

    property string icon: ""
    property bool enabled: true
    property bool busy: false
    property int buttonSize: 40
    property int iconSize: 21
    signal clicked()

    width: buttonSize
    height: buttonSize
    radius: Size.rounding.full
    opacity: enabled ? 1 : 0.35
    color: ma.pressed
        ? Color.withAlpha(Color.text, 0.14)
        : (ma.containsMouse ? Color.withAlpha(Color.text, 0.08) : "transparent")
    Behavior on color { CAnim {} }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: root.icon
        font.family: Size.fontIcon
        font.pixelSize: root.iconSize
        color: root.busy ? Color.primary : Color.textMuted

        // 装饰性/刷新动画，不走令牌（plan.md 白名单）
        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.busy
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
