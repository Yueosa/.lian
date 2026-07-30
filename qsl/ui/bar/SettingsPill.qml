// SettingsPill — 顶栏最右设置入口（不绑快捷键）
// 常驻 34px；hover 无视觉变化

import QtQuick
import Quickshell
import qs.data.state

Item {
    id: root

    readonly property int buttonSize: 34

    implicitHeight: 36
    implicitWidth: 40

    Rectangle {
        anchors.centerIn: parent
        width: root.buttonSize
        height: root.buttonSize
        radius: width / 2
        color: Color.background

        Text {
            anchors.centerIn: parent
            text: "settings"
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.lg
            color: Color.primary
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"])
    }
}
