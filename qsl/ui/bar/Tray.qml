// Tray — 系统托盘药丸（无 MultiEffect 阴影）

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.data.state

Item {
    id: root

    implicitHeight: 36
    implicitWidth: content.width + 24

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Size.spacing.md

        Repeater {
            model: SystemTray.items
            delegate: TrayItem {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
