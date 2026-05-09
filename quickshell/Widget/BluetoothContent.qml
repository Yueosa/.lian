import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Services
import qs.config
import qs.Widget.common

WidgetPanel {
    id: root
    title: "蓝牙"
    icon: "bluetooth"
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "bluetooth"
    property string mdFont: "Material Symbols Outlined"
    property string expandedMac: ""

    function boolText(value) {
        return value ? "是" : "否";
    }

    onIsActiveChanged: {
        if (isActive)
            Bluetooth.refresh();
    }

    headerTools: RowLayout {
        spacing: Sizes.spacing.md

        Text {
            text: "settings"
            font.family: root.mdFont
            font.pixelSize: Sizes.font.title
            color: Colorscheme.on_surface_variant
            Layout.alignment: Qt.AlignVCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["blueman-manager"])
            }
        }

        Rectangle {
            id: btSwitch
            width: 44
            height: 24
            radius: Sizes.rounding.normal
            color: Bluetooth.bluetoothEnabled ? Colorscheme.primary : "transparent"
            border.width: Bluetooth.bluetoothEnabled ? 0 : 2
            border.color: Colorscheme.outline
            opacity: Bluetooth.bluetoothToggling ? 0.75 : 1
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Rectangle {
                width: Bluetooth.bluetoothEnabled ? 16 : 12
                height: Bluetooth.bluetoothEnabled ? 16 : 12
                radius: width / 2
                x: Bluetooth.bluetoothEnabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: Bluetooth.bluetoothEnabled ? Colorscheme.on_primary : Colorscheme.outline

                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: Bluetooth.bluetoothToggling ? "sync" : "check"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.sm
                    font.bold: true
                    color: Colorscheme.primary
                    opacity: (Bluetooth.bluetoothEnabled || Bluetooth.bluetoothToggling) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !Bluetooth.bluetoothToggling
                cursorShape: Qt.PointingHandCursor
                onClicked: Bluetooth.toggleBluetooth()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Sizes.spacing.s

        Rectangle {
            Layout.fillWidth: true
            visible: Bluetooth.lastError !== ""
            implicitHeight: 34
            radius: Sizes.rounding.normal
            color: Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.12)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: Sizes.spacing.s

                Text {
                    text: "error"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.md
                    color: Colorscheme.error
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: Bluetooth.lastError
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.error
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Bluetooth.bluetoothEnabled

            Text {
                anchors.centerIn: parent
                text: "蓝牙已关闭"
                font.pixelSize: Sizes.font.lg
                color: Colorscheme.on_surface_variant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Bluetooth.bluetoothEnabled
            spacing: Sizes.spacing.s

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Sizes.rounding.normal
                color: Qt.alpha(Colorscheme.surface_container, 0.7)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: Sizes.spacing.s

                    Text {
                        text: Bluetooth.scanActive ? "正在扫描设备" : "扫描设备"
                        font.pixelSize: Sizes.font.sm
                        color: Colorscheme.on_surface
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Rectangle {
                        implicitWidth: 72
                        implicitHeight: 28
                        radius: Sizes.rounding.chip
                        color: Bluetooth.scanActive ? Qt.alpha(Colorscheme.primary, 0.18) : Qt.alpha(Colorscheme.primary_container, 0.8)

                        Text {
                            anchors.centerIn: parent
                            text: Bluetooth.scanActive ? "停止" : "扫描"
                            font.pixelSize: Sizes.font.xsm
                            font.bold: true
                            color: Bluetooth.scanActive ? Colorscheme.primary : Colorscheme.on_primary_container
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !Bluetooth.scanBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Bluetooth.scanActive)
                                    Bluetooth.stopScan();
                                else
                                    Bluetooth.startScan();
                            }
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn
                    width: parent.width
                    spacing: Sizes.spacing.s

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: connectedColumn.implicitHeight + 20
                        radius: Sizes.rounding.medium
                        color: Qt.alpha(Colorscheme.surface_container, 0.6)

                        ColumnLayout {
                            id: connectedColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: Sizes.spacing.xs

                            Text {
                                text: "已连接设备"
                                font.pixelSize: Sizes.font.sm
                                font.bold: true
                                color: Colorscheme.on_surface_variant
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                visible: Bluetooth.connectedDevices.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: "无已连接设备"
                                    font.pixelSize: Sizes.font.xsm
                                    color: Colorscheme.on_surface_variant
                                }
                            }

                            Repeater {
                                model: Bluetooth.connectedDevices
                                delegate: DeviceCard {
                                    Layout.fillWidth: true
                                    device: Bluetooth.connectedDevices[index] || null
                                    listType: "connected"
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: pairedColumn.implicitHeight + 20
                        radius: Sizes.rounding.medium
                        color: Qt.alpha(Colorscheme.surface_container, 0.6)

                        ColumnLayout {
                            id: pairedColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: Sizes.spacing.xs

                            Text {
                                text: "已配对设备"
                                font.pixelSize: Sizes.font.sm
                                font.bold: true
                                color: Colorscheme.on_surface_variant
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                visible: Bluetooth.pairedDevices.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: "无已配对设备"
                                    font.pixelSize: Sizes.font.xsm
                                    color: Colorscheme.on_surface_variant
                                }
                            }

                            Repeater {
                                model: Bluetooth.pairedDevices
                                delegate: DeviceCard {
                                    Layout.fillWidth: true
                                    device: Bluetooth.pairedDevices[index] || null
                                    listType: "paired"
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: scanColumn.implicitHeight + 20
                        radius: Sizes.rounding.medium
                        color: Qt.alpha(Colorscheme.surface_container, 0.6)

                        ColumnLayout {
                            id: scanColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: Sizes.spacing.xs

                            Text {
                                text: "扫描清单"
                                font.pixelSize: Sizes.font.sm
                                font.bold: true
                                color: Colorscheme.on_surface_variant
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                visible: Bluetooth.scannedDevices.length === 0
                                Text {
                                    anchors.centerIn: parent
                                    text: Bluetooth.scanActive ? "正在发现设备..." : "暂无扫描结果"
                                    font.pixelSize: Sizes.font.xsm
                                    color: Colorscheme.on_surface_variant
                                }
                            }

                            Repeater {
                                model: Bluetooth.scannedDevices
                                delegate: DeviceCard {
                                    Layout.fillWidth: true
                                    device: Bluetooth.scannedDevices[index] || null
                                    listType: "scan"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component DeviceCard: Rectangle {
        id: card

        property var device: null
        property string listType: "paired"
        readonly property bool connected: !!(device && device.connected)
        readonly property string deviceName: device && device.name ? device.name : "未知设备"
        readonly property string deviceMac: device && device.mac ? device.mac : ""
        readonly property bool expandable: listType === "connected" && connected
        readonly property bool expanded: expandable && root.expandedMac === deviceMac
        readonly property var info: deviceMac !== "" ? Bluetooth.deviceInfoByMac[deviceMac] : null
        readonly property real detailHeight: expanded ? detailColumn.implicitHeight + 8 : 0

        radius: Sizes.rounding.normal
        color: connected ? Qt.alpha(Colorscheme.primary_container, 0.8) : Qt.alpha(Colorscheme.surface, 0.7)
        implicitHeight: 50 + detailHeight

        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: Sizes.spacing.xs

            RowLayout {
                Layout.fillWidth: true
                spacing: Sizes.spacing.s

                Text {
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Sizes.font.xl
                    color: connected ? Colorscheme.primary : Colorscheme.on_surface_variant
                    text: connected ? "󰂱" : "󰂯"
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.none

                    Text {
                        Layout.fillWidth: true
                        text: deviceName
                        elide: Text.ElideRight
                        font.pixelSize: Sizes.font.md
                        font.bold: connected
                        color: connected ? Colorscheme.on_primary_container : Colorscheme.on_surface
                    }

                    Text {
                        text: listType === "scan" ? "已发现" : (listType === "connected" ? "已连接" : "已配对")
                        font.pixelSize: Sizes.font.xsm
                        color: connected ? Colorscheme.primary : Colorscheme.on_surface_variant
                    }
                }

                Rectangle {
                    implicitWidth: 60
                    implicitHeight: 28
                    radius: Sizes.rounding.chip
                    color: connected ? Qt.alpha(Colorscheme.primary, 0.15) : Qt.alpha(Colorscheme.primary_container, 0.7)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: connected ? "断开" : "连接"
                        font.pixelSize: Sizes.font.xsm
                        font.bold: true
                        color: connected ? Colorscheme.primary : Colorscheme.on_primary_container
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (deviceMac === "")
                                return;
                            if (connected)
                                Bluetooth.disconnectDevice(deviceMac);
                            else
                                Bluetooth.connectDevice(deviceMac);
                        }
                    }
                }

                Rectangle {
                    visible: expandable
                    implicitWidth: 60
                    implicitHeight: 28
                    radius: Sizes.rounding.chip
                    color: expanded ? Qt.alpha(Colorscheme.secondary, 0.18) : Qt.alpha(Colorscheme.surface_container, 0.8)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: expanded ? "收起" : "详情"
                        font.pixelSize: Sizes.font.xsm
                        font.bold: true
                        color: expanded ? Colorscheme.secondary : Colorscheme.on_surface_variant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (deviceMac === "")
                                return;
                            if (root.expandedMac === deviceMac)
                                root.expandedMac = "";
                            else {
                                root.expandedMac = deviceMac;
                                Bluetooth.requestDeviceInfo(deviceMac);
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: detailHeight
                visible: expanded || height > 0
                opacity: expanded ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ColumnLayout {
                    id: detailColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: Sizes.spacing.xxs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s

                        Text {
                            text: "设备详情"
                            font.pixelSize: Sizes.font.xsm
                            font.bold: true
                            color: Colorscheme.on_surface_variant
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        text: "MAC: " + (deviceMac !== "" ? deviceMac : "未知")
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && !!info.alias
                        text: "别名: " + info.alias
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && !!info.icon
                        text: "类型: " + info.icon
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && !!info.battery
                        text: "电量: " + info.battery
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && info.trusted !== undefined
                        text: "已信任: " + root.boolText(info.trusted)
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && info.paired !== undefined
                        text: "已配对: " + root.boolText(info.paired)
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }

                    Text {
                        visible: !!info && info.rssi !== undefined
                        text: "信号: " + info.rssi
                        font.pixelSize: Sizes.font.xsm
                        color: Colorscheme.on_surface_variant
                    }
                }
            }
        }
    }
}
