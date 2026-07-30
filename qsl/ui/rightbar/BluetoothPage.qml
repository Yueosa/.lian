// BluetoothPage — Rightbar 蓝牙页
// 对齐 Audio/Updates/Network：工具行 + 摘要卡 + 分区列表
//
// 性能：进页 detailActive+扫描；销毁停扫；ListView reuseItems；无常驻 Timer

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    signal requestClose()

    property var forgetTarget: null

    Component.onCompleted: Bluetooth.setDetailActive(true)

    Component.onDestruction: {
        root.forgetTarget = null
        Bluetooth.setDetailActive(false)
    }

    function deviceIcon(dev) {
        if (!dev)
            return "bluetooth"
        const ic = (dev.icon || "").toLowerCase()
        if (ic.indexOf("audio") >= 0 || ic.indexOf("headset") >= 0 || ic.indexOf("headphone") >= 0)
            return "headphones"
        if (ic.indexOf("input") >= 0 || ic.indexOf("keyboard") >= 0)
            return "keyboard"
        if (ic.indexOf("mouse") >= 0)
            return "mouse"
        if (ic.indexOf("phone") >= 0)
            return "smartphone"
        if (ic.indexOf("computer") >= 0 || ic.indexOf("laptop") >= 0)
            return "laptop"
        return "bluetooth"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        // 工具行：blueman + 扫描 + 开关
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            QslIconButton {
                buttonSize: 36
                iconSize: Size.fontSize.xl
                icon: "settings"
                onClicked: {
                    Bluetooth.openBlueman()
                    root.requestClose()
                }
            }

            QslIconButton {
                buttonSize: 36
                iconSize: Size.fontSize.xl
                icon: "refresh"
                busy: Bluetooth.discovering
                enabled: Bluetooth.enabled
                onClicked: Bluetooth.toggleScan()
            }

            Item { Layout.fillWidth: true }

            QslSwitch {
                sizeScale: 0.8
                checked: Bluetooth.enabled
                onToggled: (wantOn) => {
                    if (wantOn === Bluetooth.enabled)
                        return
                    Bluetooth.toggle()
                }
            }
        }

        // 摘要卡：主连接设备 / 状态
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: Size.rounding.md
            color: Bluetooth.connectedDevices.length > 0
                ? Color.withAlpha(Color.primary, 0.12)
                : Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
            Behavior on color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Size.spacing.md

                Text {
                    text: {
                        const d = Bluetooth.primaryConnected
                        if (d)
                            return root.deviceIcon(d)
                        return Bluetooth.summaryIcon
                    }
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Bluetooth.connectedDevices.length > 0
                        ? Color.primary
                        : Color.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: Bluetooth.summaryTitle
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Bluetooth.connectedDevices.length > 0
                            ? Color.primary
                            : Color.text
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Bluetooth.summarySubtitle
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                }

                // 主设备快捷断开
                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    visible: !!Bluetooth.primaryConnected

                    Text {
                        anchors.centerIn: parent
                        text: "link_off"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                        color: Color.textMuted
                        opacity: sumDiscMa.containsMouse ? 1 : 0.75
                    }
                    MouseArea {
                        id: sumDiscMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Bluetooth.primaryConnected)
                                Bluetooth.disconnectDevice(Bluetooth.primaryConnected)
                        }
                    }
                }

                Text {
                    visible: Bluetooth.connectedDevices.length > 0
                    text: Bluetooth.connectedDevices.length > 1
                        ? Bluetooth.connectedDevices.length.toString()
                        : "check"
                    font.family: Bluetooth.connectedDevices.length > 1
                        ? Size.fontMono
                        : Size.fontIcon
                    font.bold: Bluetooth.connectedDevices.length > 1
                    font.pixelSize: Size.fontSize.lg
                    color: Color.primary
                }
            }
        }

        // 扫描细条
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Bluetooth.discovering ? 3 : 0
            radius: 2
            color: Color.withAlpha(Color.primary, 0.25)
            clip: true
            opacity: Bluetooth.discovering ? 1 : 0
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Bluetooth.discovering

                SequentialAnimation on x {
                    running: Bluetooth.discovering
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -width
                        to: parent.width
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // 错误条
        Rectangle {
            Layout.fillWidth: true
            visible: Bluetooth.lastError !== ""
            implicitHeight: visible ? 34 : 0
            radius: Size.rounding.sm
            color: Color.withAlpha(Color.error, 0.12)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: Size.spacing.sm
                Text {
                    text: "error"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.md
                    color: Color.error
                }
                Text {
                    Layout.fillWidth: true
                    text: Bluetooth.lastError
                    color: Color.error
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }
            }
        }

        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            reuseItems: true
            model: Bluetooth.flatRows
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: !Bluetooth.hasAdapter
                text: "未找到蓝牙适配器"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: Bluetooth.hasAdapter && !Bluetooth.enabled
                text: "蓝牙已关闭"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: Bluetooth.enabled
                    && deviceList.count === 0
                    && Bluetooth.discovering
                text: "正在扫描…"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: Bluetooth.enabled
                    && deviceList.count === 0
                    && !Bluetooth.discovering
                text: "附近没有设备"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            delegate: Item {
                id: row
                width: ListView.view ? ListView.view.width : 0
                height: isHeader ? 28 : (askingForget ? baseH + forgetH : baseH)

                required property var modelData
                readonly property bool isHeader: modelData && modelData.kind === "header"
                readonly property var dev: (!isHeader && modelData) ? modelData.device : null
                readonly property string section: modelData ? (modelData.section || "") : ""
                readonly property bool askingForget: root.forgetTarget === dev
                readonly property int baseH: 56
                readonly property int forgetH: 44
                readonly property bool busy: Bluetooth.isBusy(dev)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isHeader
                    text: {
                        if (!modelData)
                            return ""
                        const n = modelData.count || 0
                        return modelData.title + (n > 0 ? (" · " + n) : "")
                    }
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.xsm
                    font.bold: true
                }

                Rectangle {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: row.askingForget ? row.baseH + row.forgetH : row.baseH
                    visible: !row.isHeader
                    radius: Size.rounding.md
                    clip: false
                    color: {
                        if (!row.dev)
                            return "transparent"
                        if (row.dev.connected || row.askingForget)
                            return Color.withAlpha(Color.primary, 0.12)
                        if (rowMa.containsMouse)
                            return Color.withAlpha(Color.text, 0.08)
                        return Color.withAlpha(Color.text, 0.04)
                    }

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 140 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: Size.spacing.md

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: root.deviceIcon(row.dev)
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.xl
                                color: row.dev && row.dev.connected
                                    ? Color.primary
                                    : Color.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: Bluetooth.displayName(row.dev)
                                    font.bold: !!(row.dev && row.dev.connected)
                                    font.pixelSize: Size.fontSize.md
                                    color: row.dev && row.dev.connected
                                        ? Color.primary
                                        : Color.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: Bluetooth.statusHint(row.dev, row.section)
                                    font.pixelSize: Size.fontSize.xsm
                                    color: Color.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                visible: row.section === "paired"
                                    || row.section === "connected"

                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "\uf1f8"
                                    font.family: Size.fontMono
                                    font.pixelSize: 16
                                    color: Color.textMuted
                                    opacity: forgetMa.containsMouse ? 1 : 0.75
                                }
                                MouseArea {
                                    id: forgetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.forgetTarget = root.forgetTarget === row.dev
                                            ? null
                                            : row.dev
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                visible: row.busy
                                    || (row.dev && row.dev.connected)
                                    || (row.section === "paired" && !row.askingForget)
                                text: row.busy ? "sync"
                                    : (row.dev && row.dev.connected ? "check" : "link")
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.lg
                                color: row.dev && row.dev.connected
                                    ? Color.primary
                                    : Color.textMuted

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: row.busy
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: row.askingForget
                            spacing: Size.spacing.sm

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: "忘记此设备？"
                                color: Color.textMuted
                                font.pixelSize: Size.fontSize.sm
                            }
                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 28
                                radius: Size.rounding.sm
                                color: Color.withAlpha(Color.text, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: "取消"
                                    font.pixelSize: Size.fontSize.xsm
                                    color: Color.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.forgetTarget = null
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 28
                                radius: Size.rounding.sm
                                color: Color.withAlpha(Color.error, 0.2)
                                Text {
                                    anchors.centerIn: parent
                                    text: "忘记"
                                    font.pixelSize: Size.fontSize.xsm
                                    font.bold: true
                                    color: Color.error
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Bluetooth.forgetDevice(row.dev)
                                        root.forgetTarget = null
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        anchors.rightMargin: 72
                        anchors.bottomMargin: row.askingForget ? row.forgetH : 0
                        hoverEnabled: true
                        z: -1
                        enabled: !!row.dev && !row.busy
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!row.dev)
                                return
                            if (row.section === "connected") {
                                Bluetooth.disconnectDevice(row.dev)
                                root.forgetTarget = null
                                return
                            }
                            if (row.section === "paired") {
                                Bluetooth.connectDevice(row.dev)
                                root.forgetTarget = null
                                return
                            }
                            Bluetooth.pairDevice(row.dev)
                        }
                    }
                }
            }
        }
    }
}
