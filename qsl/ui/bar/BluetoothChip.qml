// BluetoothChip — 悬停展开首个已连设备名；无点击
// 用 chipLabel / chipConnected，不依赖 detailActive

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse

    implicitHeight: 28
    implicitWidth: isHovered ? Math.ceil(layout.implicitWidth) + 14 : 28
    radius: height / 2
    clip: true
    // 有已连设备才 primary，对齐 WiFi「已连接」语义
    color: Bluetooth.chipConnected
        ? Color.withAlpha(Color.primary, 0.22)
        : Color.withAlpha(Color.text, 0.08)

    Behavior on implicitWidth {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    Behavior on color { ColorAnimation { duration: 200 } }

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
            color: Bluetooth.chipConnected
                ? Color.primary
                : (Bluetooth.enabled ? Color.text : Color.textMuted)
            text: Bluetooth.chipConnected ? "bluetooth_connected" : "bluetooth"
        }

        Text {
            id: label
            text: Bluetooth.chipLabel
            font.bold: true
            font.pixelSize: Size.fontSize.sm
            color: Color.text
            Layout.alignment: Qt.AlignVCenter
            opacity: root.isHovered ? 1 : 0
            Layout.preferredWidth: root.isHovered
                ? Math.min(label.implicitWidth, 140)
                : 0
            Layout.maximumWidth: 140
            elide: Text.ElideRight
            clip: true
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
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
