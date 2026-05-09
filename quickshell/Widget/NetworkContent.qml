import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Quickshell
import qs.Services
import qs.config
import qs.Widget.common

WidgetPanel {
    id: root
    title: "WI-FI"
    icon: "wifi"
    closeAction: () => WidgetState.qsOpen = false

    property bool isActive: WidgetState.qsOpen && WidgetState.qsView === "network"
    property string mdFont: "Material Symbols Outlined"

    Component {
        id: elementMoveNumberAnimation

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    onIsActiveChanged: {
        if (isActive) {
            Network.enableWifi();
            Network.rescanWifi();
        }
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
                onClicked: Quickshell.execDetached(["kitty", "-e", "nmtui"])
            }
        }

        Rectangle {
            id: mainSwitch
            width: 44; height: 24; radius: Sizes.rounding.normal
            color: Network.wifiEnabled ? Colorscheme.primary : "transparent"
            border.width: Network.wifiEnabled ? 0 : 2
            border.color: Colorscheme.outline
            opacity: Network.wifiToggling ? 0.75 : 1
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                width: Network.wifiEnabled ? 16 : 12
                height: Network.wifiEnabled ? 16 : 12
                radius: width / 2
                x: Network.wifiEnabled ? parent.width - width - 4 : 6
                anchors.verticalCenter: parent.verticalCenter
                color: Network.wifiEnabled ? Colorscheme.on_primary : Colorscheme.outline

                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: Network.wifiToggling ? "sync" : "check"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.sm
                    font.bold: true
                    color: Colorscheme.primary
                    opacity: (Network.wifiEnabled || Network.wifiToggling) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                enabled: !Network.wifiToggling
                onClicked: Network.toggleWifi()
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Sizes.spacing.s

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: Sizes.rounding.medium
            color: Network.ethernetConnection !== ""
                ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12)
                : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)

            Behavior on color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: Sizes.spacing.md

                Text {
                    text: "settings_ethernet"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.display
                    color: Network.ethernetConnection !== "" ? Colorscheme.primary : Colorscheme.on_surface_variant
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Sizes.spacing.none

                    Text {
                        text: "以太网"
                        font.bold: true
                        font.pixelSize: Sizes.font.lg
                        color: Network.ethernetConnection !== "" ? Colorscheme.primary : Colorscheme.on_surface
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Text {
                        text: Network.ethernetConnection !== "" ? Network.ethernetConnection : "未连接"
                        font.pixelSize: Sizes.font.sm
                        color: Colorscheme.on_surface_variant
                    }
                }

                Text {
                    visible: Network.ethernetConnection !== ""
                    text: "check"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.h1
                    color: Colorscheme.primary
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: Network.wifiScanning ? 4 : 0
            opacity: Network.wifiScanning ? 1 : 0
            indeterminate: true
            Material.accent: Colorscheme.primary

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: Network.wifiLastError !== ""
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
                    text: Network.wifiLastError
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.error
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        ListView {
            id: wifiList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Sizes.spacing.none
            model: Network.friendlyWifiNetworks
            property real removeOvershoot: 20

            delegate: WifiNetworkItem {
                required property var modelData
                width: ListView.view.width
                wifiNetwork: modelData
            }

            add: Transition {
                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
            addDisplaced: Transition {
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; to: wifiList.width + wifiList.removeOvershoot; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                }
            }
            removeDisplaced: Transition {
                NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
            }
        }
    }

    component WifiNetworkItem: Rectangle {
        id: itemRoot

        required property var wifiNetwork
        readonly property bool networkActive: wifiNetwork && wifiNetwork.active
        readonly property bool networkSecure: wifiNetwork && wifiNetwork.isSecure
        readonly property bool networkAskingPassword: wifiNetwork && wifiNetwork.askingPassword
        readonly property int networkStrength: wifiNetwork ? wifiNetwork.strength : 0
        readonly property string networkSsid: wifiNetwork ? wifiNetwork.ssid : "未知网络"
        readonly property bool publicPortalShown: itemRoot.networkActive && !itemRoot.networkSecure
        readonly property real verticalPadding: 12
        readonly property real baseHeight: networkRow.implicitHeight + itemRoot.verticalPadding * 2
        readonly property real passwordPromptTargetHeight: itemRoot.networkAskingPassword ? passwordPromptContent.implicitHeight + 8 : 0
        readonly property real publicPortalTargetHeight: itemRoot.publicPortalShown ? publicPortalContent.implicitHeight + 8 : 0

        height: itemRoot.baseHeight + itemRoot.passwordPromptTargetHeight + itemRoot.publicPortalTargetHeight
        radius: Sizes.rounding.medium
        clip: true
        color: {
            if (itemRoot.networkActive || itemRoot.networkAskingPassword)
                return Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12)
            if (mouseArea.pressed)
                return Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.12)
            if (mouseArea.containsMouse)
                return Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.08)
            return "transparent"
        }
        enabled: !(Network.wifiConnectTarget === itemRoot.wifiNetwork && !itemRoot.networkActive)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on height {
            animation: elementMoveNumberAnimation.createObject(this)
        }
        Behavior on y {
            animation: elementMoveNumberAnimation.createObject(this)
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Network.connectToWifiNetwork(itemRoot.wifiNetwork)
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 14
                rightMargin: 14
                topMargin: itemRoot.verticalPadding
            }
            spacing: Sizes.spacing.none

            RowLayout {
                id: networkRow

                Layout.fillWidth: true
                spacing: Sizes.spacing.md

                Text {
                    text: itemRoot.networkStrength > 80 ? "signal_wifi_4_bar"
                        : itemRoot.networkStrength > 60 ? "network_wifi_3_bar"
                        : itemRoot.networkStrength > 40 ? "network_wifi_2_bar"
                        : itemRoot.networkStrength > 20 ? "network_wifi_1_bar"
                        : "signal_wifi_0_bar"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.display
                    color: itemRoot.networkActive ? Colorscheme.primary : Colorscheme.on_surface_variant
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Sizes.spacing.none

                    Text {
                        Layout.fillWidth: true
                        text: itemRoot.networkSsid
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        font.bold: true
                        font.pixelSize: Sizes.font.lg
                        color: itemRoot.networkActive ? Colorscheme.primary : Colorscheme.on_surface
                    }
                }

                Text {
                    visible: itemRoot.networkSecure || itemRoot.networkActive || Network.wifiConnectTarget === itemRoot.wifiNetwork
                    text: itemRoot.networkActive ? "check"
                        : Network.wifiConnectTarget === itemRoot.wifiNetwork ? "settings_ethernet"
                        : "lock"
                    font.family: root.mdFont
                    font.pixelSize: Sizes.font.h1
                    color: itemRoot.networkActive ? Colorscheme.primary : Colorscheme.on_surface_variant
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Item {
                id: passwordPromptClip

                Layout.fillWidth: true
                Layout.preferredHeight: itemRoot.passwordPromptTargetHeight
                visible: itemRoot.networkAskingPassword || height > 0
                opacity: itemRoot.networkAskingPassword ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    animation: elementMoveNumberAnimation.createObject(this)
                }
                Behavior on height {
                    animation: elementMoveNumberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: elementMoveNumberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: passwordPromptContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 8
                    }
                    spacing: Sizes.spacing.sm

                    MaterialPasswordField {
                        id: passwordField
                        Layout.fillWidth: true
                        placeholderText: "密码"
                        onAccepted: Network.changePassword(itemRoot.wifiNetwork, text)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.sm

                        Item { Layout.fillWidth: true }
                        ActionButton {
                            text: "取消"
                            onClicked: {
                                passwordField.text = "";
                                passwordField.focus = false;
                                itemRoot.wifiNetwork.askingPassword = false;
                            }
                        }
                        ActionButton {
                            text: "连接"
                            onClicked: Network.changePassword(itemRoot.wifiNetwork, passwordField.text)
                        }
                    }
                }
            }

            Item {
                id: publicPortalClip

                Layout.fillWidth: true
                Layout.preferredHeight: itemRoot.publicPortalTargetHeight
                visible: itemRoot.publicPortalShown || height > 0
                opacity: itemRoot.publicPortalShown ? 1 : 0
                clip: true

                Behavior on Layout.preferredHeight {
                    animation: elementMoveNumberAnimation.createObject(this)
                }
                Behavior on height {
                    animation: elementMoveNumberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: elementMoveNumberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: publicPortalContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 8
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        text: "打开网络门户"
                        filled: true
                        onClicked: {
                            Network.openPublicWifiPortal();
                            WidgetState.qsOpen = false;
                        }
                    }
                }
            }
        }
    }

    component MaterialPasswordField: TextField {
        id: fieldRoot

        Material.theme: Material.System
        Material.accent: Colorscheme.primary
        Material.primary: Colorscheme.primary
        Material.background: Colorscheme.surface
        Material.foreground: Colorscheme.on_surface
        Material.containerStyle: Material.Outlined

        implicitHeight: 56
        property bool blinkOn: true
        renderType: Text.QtRendering
        selectedTextColor: Colorscheme.on_secondary_container
        selectionColor: Colorscheme.secondary_container
        placeholderTextColor: Colorscheme.outline
        clip: true
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        selectByMouse: true
        wrapMode: TextEdit.Wrap

        font {
            pixelSize: 15
            hintingPreference: Font.PreferFullHinting
        }

        cursorDelegate: Rectangle {
            width: 2
            radius: Sizes.rounding.hairline
            color: Colorscheme.primary
            visible: fieldRoot.activeFocus && fieldRoot.blinkOn
        }

        onActiveFocusChanged: {
            fieldRoot.blinkOn = true;
            if (activeFocus)
                cursorBlinkTimer.restart();
            else
                cursorBlinkTimer.stop();
        }

        Timer {
            id: cursorBlinkTimer
            interval: 530
            repeat: true
            running: fieldRoot.activeFocus
            onTriggered: fieldRoot.blinkOn = !fieldRoot.blinkOn
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
        }
    }

    component ActionButton: Rectangle {
        id: actionButton

        property alias text: label.text
        property bool filled: false
        signal clicked()

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 34
        radius: height / 2
        color: filled
            ? (buttonMouse.pressed ? Colorscheme.primary_container
               : buttonMouse.containsMouse ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.85)
               : Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.7))
            : (buttonMouse.pressed ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.20)
               : buttonMouse.containsMouse ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12)
               : "transparent")

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            id: label
            anchors.centerIn: parent
            font.pixelSize: Sizes.font.sm
            font.bold: true
            color: Colorscheme.primary

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }
}
