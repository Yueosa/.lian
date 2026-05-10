import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.config

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse

    implicitHeight: 28
    implicitWidth: isHovered ? (layout.width + 20) : 28
    radius: height / 2
    color: Bluetooth.bluetoothEnabled ? Colorscheme.primary_container : Colorscheme.surface_container

    Behavior on implicitWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 250 } }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Sizes.spacing.s

        Text {
            id: iconText
            font.family: Sizes.fontFamilyMono
            font.pixelSize: Sizes.font.lg
            Layout.alignment: Qt.AlignVCenter
            color: Bluetooth.bluetoothEnabled ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
            text: Bluetooth.bluetoothConnected ? "󰂱" : (Bluetooth.bluetoothEnabled ? "󰂯" : "󰂲")
        }

        Text {
            text: Bluetooth.bluetoothConnected ? Bluetooth.connectedDeviceName : (Bluetooth.bluetoothEnabled ? "已开启" : "已关闭")
            font.bold: true
            font.pixelSize: Sizes.font.sm
            color: Bluetooth.bluetoothEnabled ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
            Layout.alignment: Qt.AlignVCenter
            visible: root.isHovered
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (WidgetState.qsOpen && WidgetState.qsView === "bluetooth") {
                WidgetState.qsOpen = false;
            } else {
                WidgetState.qsView = "bluetooth";
                WidgetState.qsOpen = true;
            }
        }
    }
}
