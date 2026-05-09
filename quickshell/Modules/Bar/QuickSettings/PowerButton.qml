import QtQuick
import Quickshell
import qs.config

Rectangle {
    id: root
    property bool isHovered: mouseArea.containsMouse
    property real iconSize: isHovered ? 16 : 14

    color: Colorscheme.error
    radius: height / 2
    implicitHeight: isHovered ? 34 : 28
    implicitWidth: isHovered ? 34 : 28

    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on iconSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/wlogout/scripts/logoutlaunch.sh"])
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "⏻"
        font.pixelSize: root.iconSize
        font.bold: true
        color: Colorscheme.on_error 
    }
}
