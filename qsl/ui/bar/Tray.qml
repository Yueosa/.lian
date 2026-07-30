// Tray — 常驻 pin + expand overflow（无 MultiEffect）
// model 直接用 SystemTray.items；pinSignature 驱动立刻刷新
// overflow 用 Loader：关闭即销毁

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs.data.state
import qs.data.service

Item {
    id: root

    property var screen: null
    property bool trayOverflowOpen: false

    implicitHeight: 36
    implicitWidth: Math.max(36, content.implicitWidth + 24)

    function closeOverflow() {
        root.trayOverflowOpen = false
    }

    function relayoutBar() {
        if (content.forceLayout)
            content.forceLayout()
    }

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Size.spacing.md

        Text {
            visible: TrayService.unpinnedCount > 0
            text: "expand_more"
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.lg
            color: root.trayOverflowOpen ? Color.primary : Color.textMuted
            rotation: root.trayOverflowOpen ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: Size.anim.fast; easing.type: Easing.OutCubic }
            }
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.trayOverflowOpen)
                        root.closeOverflow()
                    else
                        root.trayOverflowOpen = true
                }
            }
        }

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: barSlot
                required property var modelData

                // 不用函数绑定猜依赖：显式听 pinSignature
                property bool show: false

                function syncShow() {
                    barSlot.show = TrayService.isPinned(barSlot.modelData)
                }

                Component.onCompleted: syncShow()
                Connections {
                    target: TrayService
                    function onPinSignatureChanged() { barSlot.syncShow() }
                    function onRevisionChanged() { barSlot.syncShow() }
                }

                visible: show
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: show ? 20 : 0
                Layout.preferredHeight: show ? 20 : 0
                Layout.maximumWidth: show ? 20 : 0
                implicitWidth: show ? 20 : 0
                implicitHeight: show ? 20 : 0
                width: show ? 20 : 0
                height: show ? 20 : 0
                clip: true
                opacity: show ? 1 : 0

                TrayItem {
                    anchors.fill: parent
                    modelData: barSlot.modelData
                    // 先让栏刷新，再关 overflow（同帧关窗会感觉「没立刻刷新」）
                    onPinChanged: {
                        root.relayoutBar()
                        Qt.callLater(root.closeOverflow)
                    }
                }
            }
        }
    }

    Connections {
        target: TrayService
        function onPinSignatureChanged() {
            root.relayoutBar()
        }
        function onUnpinnedCountChanged() {
            if (TrayService.unpinnedCount === 0)
                root.closeOverflow()
        }
    }

    Loader {
        active: root.trayOverflowOpen && TrayService.unpinnedCount > 0
        sourceComponent: overflowComp
    }

    Component {
        id: overflowComp

        PanelWindow {
            id: overflowPopup

            screen: root.screen
            color: "transparent"
            exclusiveZone: -1
            visible: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "qsl-tray-overflow"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            mask: Region { item: overflowMask }

            Item {
                id: overflowMask
                anchors.fill: parent
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: root.closeOverflow()
            }

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    root.closeOverflow()
                    event.accepted = true
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 52
                    anchors.rightMargin: 12
                    width: overflowGrid.implicitWidth + 20
                    height: overflowGrid.implicitHeight + 20
                    radius: Size.rounding.lg
                    color: Color.background
                    border.width: 1
                    border.color: Color.outlineVariant

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {}
                    }

                    GridLayout {
                        id: overflowGrid
                        anchors.centerIn: parent
                        columns: Math.max(1, Math.ceil(Math.sqrt(Math.max(1, TrayService.unpinnedCount))))
                        columnSpacing: Size.spacing.md
                        rowSpacing: Size.spacing.md

                        Repeater {
                            model: SystemTray.items

                            delegate: Item {
                                id: ovSlot
                                required property var modelData

                                property bool show: false

                                function syncShow() {
                                    ovSlot.show = TrayService.inOverflow(ovSlot.modelData)
                                }

                                Component.onCompleted: syncShow()
                                Connections {
                                    target: TrayService
                                    function onPinSignatureChanged() { ovSlot.syncShow() }
                                    function onRevisionChanged() { ovSlot.syncShow() }
                                }

                                visible: show
                                Layout.preferredWidth: show ? 20 : 0
                                Layout.preferredHeight: show ? 20 : 0
                                Layout.maximumWidth: show ? 20 : 0
                                width: show ? 20 : 0
                                height: show ? 20 : 0
                                clip: true

                                TrayItem {
                                    anchors.fill: parent
                                    modelData: ovSlot.modelData
                                    onPinChanged: {
                                        root.relayoutBar()
                                        Qt.callLater(root.closeOverflow)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
