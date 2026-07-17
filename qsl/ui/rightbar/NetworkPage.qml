// NetworkPage — Rightbar 网络页
// 参考旧 NetworkContent：以太网卡片、扫描条、列表行展开密码框
//
// 性能：进页 detailActive+扫描；销毁停扫描并清密码态；ListView reuseItems

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.data.service

Item {
    id: root

    signal requestClose()

    Component.onCompleted: {
        Network.setDetailActive(true)
    }

    Component.onDestruction: {
        Network.setDetailActive(false)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        // 工具行：nmtui + 刷新 + WiFi 开关
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: nmtuiMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Color.textMuted
                }
                MouseArea {
                    id: nmtuiMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Network.openNmtui()
                        root.requestClose()
                    }
                }
            }

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: scanMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"
                opacity: Network.wifiEnabled ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "refresh"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Network.wifiScanning ? Color.primary : Color.textMuted
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: Network.wifiScanning
                    }
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Network.wifiEnabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Network.scanWifi()
                }
            }

            Item { Layout.fillWidth: true }

            // WiFi 开关
            Rectangle {
                id: wifiSwitch
                width: 44
                height: 24
                radius: height / 2
                color: Network.wifiEnabled ? Color.primary : "transparent"
                border.width: Network.wifiEnabled ? 0 : 2
                border.color: Color.outline
                Behavior on color { ColorAnimation { duration: 200 } }

                Rectangle {
                    width: Network.wifiEnabled ? 16 : 12
                    height: width
                    radius: width / 2
                    x: Network.wifiEnabled ? parent.width - width - 4 : 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: Network.wifiEnabled ? Color.textOnPrimary : Color.outline
                    Behavior on x {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    Behavior on width {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const turningOn = !Network.wifiEnabled
                        Network.toggleWifi()
                        if (turningOn)
                            Qt.callLater(() => Network.scanWifi())
                    }
                }
            }
        }

        // 以太网
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Size.rounding.md
            color: Network.ethernetConnected
                ? Color.withAlpha(Color.primary, 0.12)
                : Color.withAlpha(Color.text, 0.06)
            Behavior on color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Size.spacing.md

                Text {
                    text: "settings_ethernet"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Network.ethernetConnected ? Color.primary : Color.textMuted
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: "以太网"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Network.ethernetConnected ? Color.primary : Color.text
                    }
                    Text {
                        text: Network.ethernetConnected
                            ? (Network.ethernetName
                                + (Network.ethernetLinkSpeed > 0
                                    ? (" · " + Network.ethernetLinkSpeed + " Mbps")
                                    : ""))
                            : "未连接"
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Text {
                    visible: Network.ethernetConnected
                    text: "check"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.lg
                    color: Color.primary
                }
            }
        }

        // 扫描细条
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Network.wifiScanning ? 3 : 0
            radius: 2
            color: Color.withAlpha(Color.primary, 0.25)
            clip: true
            opacity: Network.wifiScanning ? 1 : 0
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Network.wifiScanning

                SequentialAnimation on x {
                    running: Network.wifiScanning
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
            visible: Network.lastError !== ""
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
                    text: Network.lastError
                    color: Color.error
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }
            }
        }

        ListView {
            id: wifiList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            reuseItems: true
            model: Network.wifiNetworks
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: wifiList.count === 0 && Network.wifiEnabled
                text: !Network.hasWifiDevice
                    ? "未找到 WiFi 设备"
                    : (Network.wifiScanning ? "正在扫描…" : "附近没有网络")
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: !Network.wifiEnabled
                text: "WiFi 已关闭"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            delegate: Rectangle {
                id: row
                width: ListView.view ? ListView.view.width : 0
                radius: Size.rounding.md
                clip: true

                required property var modelData
                readonly property var net: modelData
                readonly property bool active: !!(net && net.connected)
                readonly property bool secure: Network.isSecure(net)
                readonly property bool asking: Network.passwordNetwork === net
                readonly property bool connecting: Network.connectTarget === net && !active
                readonly property bool portal: active && !secure
                readonly property real strength: net ? (net.signalStrength || 0) : 0

                readonly property int pad: 12
                readonly property real baseH: 52
                readonly property real passH: asking ? (passCol.implicitHeight + 10) : 0
                readonly property real portalH: portal ? (portalCol.implicitHeight + 10) : 0

                height: baseH + passH + portalH

                color: {
                    if (active || asking)
                        return Color.withAlpha(Color.primary, 0.12)
                    if (rowMa.containsMouse)
                        return Color.withAlpha(Color.text, 0.08)
                    return "transparent"
                }

                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 140 } }

                function strengthIcon() {
                    if (row.strength > 0.8)
                        return "signal_wifi_4_bar"
                    if (row.strength > 0.6)
                        return "network_wifi_3_bar"
                    if (row.strength > 0.4)
                        return "network_wifi_2_bar"
                    if (row.strength > 0.2)
                        return "network_wifi_1_bar"
                    return "signal_wifi_0_bar"
                }

                ColumnLayout {
                    id: mainCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 14
                        rightMargin: 14
                        topMargin: row.pad
                    }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: row.baseH - row.pad * 2
                        spacing: Size.spacing.md

                        Text {
                            text: row.strengthIcon()
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.xl
                            color: row.active ? Color.primary : Color.textMuted
                        }

                        Text {
                            Layout.fillWidth: true
                            // _netRev / _ssidFix 变更后刷新显示名（GBK SSID 补丁）
                            text: {
                                void Network._netRev
                                void Network._ssidFix
                                return Network.displayName(net)
                            }
                            font.bold: true
                            font.pixelSize: Size.fontSize.md
                            color: row.active ? Color.primary : Color.text
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: row.secure || row.active || row.connecting
                            text: row.active ? "check"
                                : (row.connecting ? "sync" : "lock")
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.lg
                            color: row.active ? Color.primary : Color.textMuted
                        }
                    }

                    // 密码展开区（旧版最爱的交互）
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: row.passH
                        visible: row.asking || height > 0.5
                        opacity: row.asking ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 160 }
                        }

                        ColumnLayout {
                            id: passCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: 8
                            }
                            spacing: Size.spacing.sm

                            // 描边密码框
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: Size.rounding.md
                                color: Color.withAlpha(Color.surface, 0.9)
                                border.width: passInput.activeFocus ? 2 : 1
                                border.color: passInput.activeFocus
                                    ? Color.primary
                                    : Color.outlineVariant
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                TextInput {
                                    id: passInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: Color.text
                                    selectedTextColor: Color.textOnPrimary
                                    selectionColor: Color.primary
                                    font.pixelSize: Size.fontSize.md
                                    clip: true
                                    inputMethodHints: Qt.ImhSensitiveData
                                    onAccepted: Network.submitPassword(row.net, text)

                                    // reuseItems 时换网展开，清掉上一行残留密码
                                    Connections {
                                        target: row
                                        function onAskingChanged() {
                                            if (row.asking)
                                                passInput.text = ""
                                        }
                                    }

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "密码"
                                        color: Color.outline
                                        font.pixelSize: Size.fontSize.md
                                        visible: !passInput.text && !passInput.activeFocus
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Size.spacing.sm
                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    implicitWidth: cancelLbl.implicitWidth + 28
                                    implicitHeight: 34
                                    radius: height / 2
                                    color: cancelMa.containsMouse
                                        ? Color.withAlpha(Color.primary, 0.12)
                                        : "transparent"
                                    Text {
                                        id: cancelLbl
                                        anchors.centerIn: parent
                                        text: "取消"
                                        font.pixelSize: Size.fontSize.sm
                                        font.bold: true
                                        color: Color.primary
                                    }
                                    MouseArea {
                                        id: cancelMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            passInput.text = ""
                                            Network.cancelPassword()
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: connectLbl.implicitWidth + 28
                                    implicitHeight: 34
                                    radius: height / 2
                                    color: connectMa.containsMouse
                                        ? Color.withAlpha(Color.primary, 0.28)
                                        : Color.withAlpha(Color.primary, 0.18)
                                    Text {
                                        id: connectLbl
                                        anchors.centerIn: parent
                                        text: "连接"
                                        font.pixelSize: Size.fontSize.sm
                                        font.bold: true
                                        color: Color.primary
                                    }
                                    MouseArea {
                                        id: connectMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Network.submitPassword(row.net, passInput.text)
                                    }
                                }
                            }
                        }

                        // 展开时抢焦点
                        onVisibleChanged: {
                            if (row.asking)
                                Qt.callLater(() => passInput.forceActiveFocus())
                        }
                    }

                    // 开放热点门户
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: row.portalH
                        visible: row.portal || height > 0.5
                        opacity: row.portal ? 1 : 0
                        clip: true

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        ColumnLayout {
                            id: portalCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: 8
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: height / 2
                                color: portalMa.containsMouse
                                    ? Color.withAlpha(Color.primary, 0.28)
                                    : Color.withAlpha(Color.primary, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: "打开网络门户"
                                    font.pixelSize: Size.fontSize.sm
                                    font.bold: true
                                    color: Color.primary
                                }
                                MouseArea {
                                    id: portalMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Network.openPublicWifiPortal()
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    anchors.bottomMargin: row.passH + row.portalH
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // 密码展开时不挡输入
                    enabled: !row.asking
                    onClicked: Network.connectToWifi(row.net)
                }
            }
        }
    }
}
