import QtQuick
import Quickshell
import qs.config

Rectangle {
    id: root
    property bool isHovered: mouseArea.containsMouse
    property real iconSize: isHovered ? 18 : 16

    color: Colorscheme.secondary_container 
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
        onClicked: WidgetState.notifOpen = !WidgetState.notifOpen
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\ue7f4"
        font.family: "Material Symbols Outlined"
        font.pixelSize: root.iconSize
        color: Colorscheme.on_secondary_container 
    }
}
