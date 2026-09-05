// WifiChip — 悬停展开 SSID / 以太网名；无点击
// 宽度跟 layout.implicitWidth，避免文字溢出胶囊

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    // 悬停意图：进入即锁存展开，由 RightBar 完全离开 1s 后统一回收（见 Bar.qml）
    property bool expanded: false

    onIsHoveredChanged: {
        if (isHovered)
            expanded = true
    }

    implicitHeight: 28
    implicitWidth: expanded ? Math.ceil(layout.implicitWidth) + 14 : 28
    radius: height / 2
    clip: true
    color: (Network.ethernetConnected || Network.wifiConnected)
        ? Color.withAlpha(Color.primary, 0.22)
        : Color.withAlpha(Color.text, 0.08)

    Behavior on implicitWidth {
        Anim { type: Anim.SpatialFast }
    }
    Behavior on color { CAnim {} }

    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 7
        spacing: Size.spacing.xs

        Text {
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.lg
            Layout.alignment: Qt.AlignVCenter
            color: (Network.ethernetConnected || Network.wifiConnected)
                ? Color.primary
                : Color.textMuted
            text: Network.chipIcon
        }

        Text {
            id: label
            text: Network.chipLabel
            font.bold: true
            font.pixelSize: Size.fontSize.sm
            color: Color.text
            Layout.alignment: Qt.AlignVCenter
            // 收起时占宽 0，展开用真实字宽（封顶），保证胶囊包住文字
            opacity: root.expanded ? 1 : 0
            Layout.preferredWidth: root.expanded
                ? Math.min(label.implicitWidth, 140)
                : 0
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            clip: true
            Behavior on opacity { Anim { type: Anim.EffectsFast } }
            Behavior on Layout.preferredWidth {
                Anim { type: Anim.SpatialFast }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }
}
