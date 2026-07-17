// WifiChip — 悬停展开 SSID / 以太网名；无点击
// 宽度跟 layout.implicitWidth，避免文字溢出胶囊

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
    color: (Network.ethernetConnected || Network.wifiConnected)
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
