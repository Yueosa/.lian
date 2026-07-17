// StatusChips — WiFi / BT / Audio 药丸容器（无 Updates、无点击开栏）

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    implicitHeight: 36
    implicitWidth: layout.width + 16

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Size.spacing.sm

        WifiChip {}
        BluetoothChip {}
        AudioChip {}
    }
}
