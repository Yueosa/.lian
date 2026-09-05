// BluetoothChip — 悬停展开首个已连设备名；无点击
// 用 chipLabel / chipConnected，不依赖 detailActive

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
    // 有已连设备才 primary，对齐 WiFi「已连接」语义
    color: Bluetooth.chipConnected
        ? Color.primaryContainer
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
            font.pixelSize: Size.iconSize.lg
            Layout.alignment: Qt.AlignVCenter
            color: Bluetooth.chipConnected
                ? Color.primaryContainerText
                : (Bluetooth.enabled ? Color.text : Color.textMuted)
            text: Bluetooth.chipConnected ? "bluetooth_connected" : "bluetooth"
        }

        Text {
            id: label
            text: Bluetooth.chipLabel
            font.bold: true
            font.pixelSize: Size.fontSize.labelMedium
            color: Bluetooth.chipConnected ? Color.primaryContainerText : Color.text
            Layout.alignment: Qt.AlignVCenter
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
