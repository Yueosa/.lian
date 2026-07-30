// NetworkPage — Rightbar 网络页
// 对齐 Audio/Updates：工具行 + 当前连接摘要卡 + 分区列表（已保存 / 附近）
//
// 性能：进页 detailActive+扫描；销毁停扫描并清密码态；ListView reuseItems；
// 分区数组仅服务层 detailActive 时构建

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

    Component.onCompleted: Network.setDetailActive(true)

    Component.onDestruction: {
        root.forgetTarget = null
        Network.setDetailActive(false)
    }

    function strengthIcon(strength) {
        const s = strength || 0
        if (s > 0.8)
            return "signal_wifi_4_bar"
        if (s > 0.6)
            return "network_wifi_3_bar"
        if (s > 0.4)
            return "network_wifi_2_bar"
        if (s > 0.2)
            return "network_wifi_1_bar"
        return "signal_wifi_0_bar"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        // 工具行：nmtui + 刷新 + WiFi 开关
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            QslIconButton {
                buttonSize: 36
                iconSize: Size.fontSize.xl
                icon: "settings"
                onClicked: {
                    Network.openNmtui()
                    root.requestClose()
                }
            }

            QslIconButton {
                buttonSize: 36
                iconSize: Size.fontSize.xl
                icon: "refresh"
                busy: Network.wifiScanning
                enabled: Network.wifiEnabled
                onClicked: Network.scanWifi()
            }

            Item { Layout.fillWidth: true }

            QslSwitch {
                sizeScale: 0.8
                checked: Network.wifiEnabled
                onToggled: (wantOn) => {
                    if (wantOn === Network.wifiEnabled)
                        return
                    Network.toggleWifi()
                    if (wantOn)
                        Qt.callLater(() => Network.scanWifi())
                }
            }
        }

        // 摘要卡：当前连接（有线优先）+ 连通性；Wi‑Fi 可断开 / 遗忘
        // 高度跟内容走，避免门户/遗忘确认被裁切
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sumCol.implicitHeight + 28
            radius: Size.rounding.md
            color: (Network.ethernetConnected || Network.wifiConnected)
                ? Color.withAlpha(Color.primary, 0.12)
                : Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
            Behavior on color { ColorAnimation { duration: 140 } }
            clip: true

            ColumnLayout {
                id: sumCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 14
                spacing: Size.spacing.sm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.md

                    Text {
                        text: Network.ethernetConnected
                            ? "settings_ethernet"
                            : (Network.wifiEnabled
                                ? (Network.wifiConnected
                                    ? root.strengthIcon(Network.wifiSignalStrength)
                                    : "wifi")
                                : "wifi_off")
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.xl
                        color: (Network.ethernetConnected || Network.wifiConnected)
                            ? Color.primary
                            : Color.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: Network.summaryTitle
                            font.bold: true
                            font.pixelSize: Size.fontSize.md
                            color: (Network.ethernetConnected || Network.wifiConnected)
                                ? Color.primary
                                : Color.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: Network.summarySubtitle
                            font.pixelSize: Size.fontSize.xsm
                            color: Color.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    // 当前 Wi‑Fi：遗忘（改密场景）
                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        visible: Network.wifiConnected
                            && !Network.ethernetConnected
                            && Network._activeWifiNetwork
                            && Network._activeWifiNetwork.known

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1f8"
                            font.family: Size.fontMono
                            font.pixelSize: 16
                            color: Color.textMuted
                            opacity: sumForgetMa.containsMouse ? 1 : 0.75
                        }
                        MouseArea {
                            id: sumForgetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const n = Network._activeWifiNetwork
                                root.forgetTarget = root.forgetTarget === n ? null : n
                            }
                        }
                    }

                    // 断开当前 Wi‑Fi
                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        visible: Network.wifiConnected && !Network.ethernetConnected

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
                            onClicked: Network.disconnectActiveWifi()
                        }
                    }

                    Text {
                        visible: Network.ethernetConnected || Network.wifiConnected
                        text: "check"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                        color: Color.primary
                    }
                }

                // 门户 / 摘要卡内遗忘确认
                RowLayout {
                    Layout.fillWidth: true
                    visible: Network.captivePortal
                        && Network.wifiConnected
                        && !Network.ethernetConnected
                    spacing: Size.spacing.sm

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
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

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.forgetTarget
                        && root.forgetTarget === Network._activeWifiNetwork
                    spacing: Size.spacing.sm

                    Text {
                        Layout.fillWidth: true
                        text: "忘记此网络？"
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
                                Network.forgetNetwork(root.forgetTarget)
                                root.forgetTarget = null
                            }
                        }
                    }
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
            model: Network.wifiFlatRows
            boundsBehavior: Flickable.StopAtBounds

            Text {
                anchors.centerIn: parent
                visible: !Network.wifiEnabled
                text: "Wi‑Fi 已关闭"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: Network.wifiEnabled
                    && wifiList.count === 0
                    && Network.wifiScanning
                text: "正在扫描…"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            Text {
                anchors.centerIn: parent
                visible: Network.wifiEnabled
                    && wifiList.count === 0
                    && !Network.wifiScanning
                text: !Network.hasWifiDevice ? "未找到 Wi‑Fi 设备" : "附近没有网络"
                color: Color.textMuted
                font.pixelSize: Size.fontSize.md
            }

            delegate: Item {
                id: row
                width: ListView.view ? ListView.view.width : 0

                required property var modelData
                readonly property bool isHeader: modelData && modelData.kind === "header"
                readonly property var net: (!isHeader && modelData) ? modelData.network : null
                readonly property string section: modelData ? (modelData.section || "") : ""
                readonly property bool secure: Network.isSecure(net)
                readonly property bool known: !!(net && net.known)
                readonly property bool asking: Network.passwordNetwork === net
                readonly property bool connecting: Network.connectTarget === net
                readonly property bool askingForget: root.forgetTarget === net
                readonly property real strength: net ? (net.signalStrength || 0) : 0
                readonly property int baseH: 56
                readonly property int forgetH: 44
                readonly property int pad: 12

                readonly property real passH: asking ? (passCol.implicitHeight + 10) : 0
                readonly property real extraH: askingForget ? forgetH : 0

                height: isHeader
                    ? 28
                    : (baseH + passH + extraH)

                // ----- section header -----
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
                    height: row.isHeader ? 0 : row.height
                    visible: !row.isHeader
                    radius: Size.rounding.md
                    clip: true
                    color: {
                        if (row.asking || row.askingForget)
                            return Color.withAlpha(Color.primary, 0.12)
                        if (rowMa.containsMouse)
                            return Color.withAlpha(Color.text, 0.08)
                        return "transparent"
                    }

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 140 } }

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
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: row.baseH - row.pad * 2
                            spacing: Size.spacing.md

                            Text {
                                text: root.strengthIcon(row.strength)
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.xl
                                color: Color.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        void Network._netRev
                                        void Network._ssidFix
                                        return Network.displayName(row.net)
                                    }
                                    font.bold: true
                                    font.pixelSize: Size.fontSize.md
                                    color: Color.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: {
                                        if (row.connecting)
                                            return "连接中…"
                                        if (row.asking)
                                            return Network.passwordHint || "输入密码"
                                        if (row.section === "saved")
                                            return row.secure ? "已保存 · 安全" : "已保存"
                                        return row.secure ? "安全网络" : "开放网络"
                                    }
                                    font.pixelSize: Size.fontSize.xsm
                                    color: Color.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            // 已保存：遗忘
                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                visible: row.known && !row.asking

                                Text {
                                    anchors.centerIn: parent
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
                                        root.forgetTarget = root.forgetTarget === row.net
                                            ? null
                                            : row.net
                                    }
                                }
                            }

                            Text {
                                visible: row.secure || row.connecting
                                text: row.connecting ? "sync" : "lock"
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.lg
                                color: Color.textMuted

                                RotationAnimator on rotation {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: row.connecting
                                }
                            }
                        }

                        // 密码展开
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: row.passH
                            visible: row.asking || height > 0.5
                            opacity: row.asking ? 1 : 0
                            clip: true

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity { NumberAnimation { duration: 160 } }

                            ColumnLayout {
                                id: passCol
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }
                                spacing: Size.spacing.sm

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
                                            text: Network.passwordHint || "密码"
                                            color: Color.outline
                                            font.pixelSize: Size.fontSize.md
                                            visible: !passInput.text && !passInput.activeFocus
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Size.spacing.sm

                                    // 改密场景：密码框旁也可遗忘
                                    Rectangle {
                                        visible: row.known
                                        implicitWidth: forgetLbl.implicitWidth + 28
                                        implicitHeight: 34
                                        radius: height / 2
                                        color: passForgetMa.containsMouse
                                            ? Color.withAlpha(Color.error, 0.18)
                                            : "transparent"
                                        Text {
                                            id: forgetLbl
                                            anchors.centerIn: parent
                                            text: "遗忘"
                                            font.pixelSize: Size.fontSize.sm
                                            font.bold: true
                                            color: Color.error
                                        }
                                        MouseArea {
                                            id: passForgetMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Network.forgetNetwork(row.net)
                                                root.forgetTarget = null
                                            }
                                        }
                                    }

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

                            onVisibleChanged: {
                                if (row.asking)
                                    Qt.callLater(() => passInput.forceActiveFocus())
                            }
                        }

                        // 行内遗忘确认
                        RowLayout {
                            Layout.fillWidth: true
                            visible: row.askingForget && !row.asking
                            spacing: Size.spacing.sm

                            Text {
                                Layout.fillWidth: true
                                text: "忘记此网络？"
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
                                        Network.forgetNetwork(row.net)
                                        root.forgetTarget = null
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        anchors.bottomMargin: row.passH + row.extraH
                        anchors.rightMargin: row.known ? 64 : 36
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !row.asking && !row.connecting
                        onClicked: {
                            root.forgetTarget = null
                            Network.connectToWifi(row.net)
                        }
                    }
                }
            }
        }
    }
}
