// SettingsPill — 顶栏最右设置入口（不绑快捷键）
// 点击 → qs ipc settings；无 MultiEffect

import QtQuick
import Quickshell
import qs.data.state

Item {
    id: root

    readonly property int buttonSize: 28
    readonly property int hoverSize: 34
    property bool isHovered: mouseArea.containsMouse

    implicitHeight: 36
    implicitWidth: 36

    Rectangle {
        anchors.centerIn: parent
        width: root.isHovered ? root.hoverSize : root.buttonSize
        height: width
        radius: width / 2
        color: Color.background

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: "settings"
            font.family: Size.fontIcon
            font.pixelSize: root.isHovered ? Size.fontSize.lg : Size.fontSize.md
            color: Color.primary
            Behavior on font.pixelSize {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"])
    }
}
