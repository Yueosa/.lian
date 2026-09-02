// StatusChips — WiFi / BT / Audio 药丸容器（无 Updates、无点击开栏）

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    implicitHeight: 36
    implicitWidth: layout.width + 16

    // RightBar 悬停判定并集（底层 MouseArea 会被 chip 挡住 hover 事件）
    readonly property bool anyHovered: wifiChip.isHovered
        || btChip.isHovered || audioChip.isHovered

    // RightBar 统一回收（见 Bar.qml）
    function collapseAll() {
        wifiChip.expanded = false
        btChip.expanded = false
        audioChip.expanded = false
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Size.spacing.sm

        WifiChip { id: wifiChip }
        BluetoothChip { id: btChip }
        AudioChip { id: audioChip }
    }
}
