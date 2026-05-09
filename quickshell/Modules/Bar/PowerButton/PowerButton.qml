import QtQuick
import Quickshell
import qs.config

Rectangle {
    id: root

    // 警告红
    color: Colorscheme.error 
    radius: height / 2
    implicitHeight: 28
    implicitWidth: 28

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/wlogout/scripts/logoutlaunch.sh"])
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "⏻"
        font.pixelSize: Sizes.font.lg 
        font.bold: true
        color: Colorscheme.on_error 
    }
}
