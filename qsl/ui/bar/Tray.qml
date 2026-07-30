// Tray — 常驻 pin + expand overflow（无 MultiEffect）
// 性能：overflow 关闭时 PanelWindow.visible=false；栏上只实例化 pinned

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.data.state
import qs.data.service

Item {
    id: root

    property var screen: null
    property bool trayOverflowOpen: false

    implicitHeight: 36
    implicitWidth: Math.max(36, content.implicitWidth + 24)

    Rectangle {
        anchors.fill: parent
        color: Color.background
        radius: height / 2
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Size.spacing.md

        // expand：有折叠项才显示
        Text {
            visible: TrayService.unpinnedItems.length > 0
            text: "expand_more"
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.lg
            color: overflowMa.containsMouse || root.trayOverflowOpen
                ? Color.primary
                : Color.textMuted
            rotation: root.trayOverflowOpen ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: Size.anim.fast; easing.type: Easing.OutCubic }
            }
            Layout.alignment: Qt.AlignVCenter

            MouseArea {
                id: overflowMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.trayOverflowOpen = !root.trayOverflowOpen
            }
        }

        Repeater {
            model: TrayService.pinnedItems
            delegate: TrayItem {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // overflow 弹出：仅有 unpinned 且打开时可见
    PanelWindow {
        id: overflowPopup

        visible: root.trayOverflowOpen && TrayService.unpinnedItems.length > 0
        screen: root.screen
        color: "transparent"
        exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        WlrLayershell.namespace: "qsl-tray-overflow"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        mask: Region { item: overflowMask }

        Item {
            id: overflowMask
            anchors.fill: parent
        }

        MouseArea {
            anchors.fill: parent
            enabled: overflowPopup.visible
            z: -1
            onClicked: root.trayOverflowOpen = false
        }

        FocusScope {
            anchors.fill: parent
            focus: overflowPopup.visible

            Keys.onEscapePressed: event => {
                root.trayOverflowOpen = false
                event.accepted = true
            }

            // 锚在顶栏右上偏左；简单固定边距，避免复杂 mapToGlobal
            Rectangle {
                id: popupBg
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

                GridLayout {
                    id: overflowGrid
                    anchors.centerIn: parent
                    columns: Math.max(1, Math.ceil(Math.sqrt(Math.max(1, TrayService.unpinnedItems.length))))
                    columnSpacing: Size.spacing.md
                    rowSpacing: Size.spacing.md

                    Repeater {
                        model: TrayService.unpinnedItems
                        delegate: TrayItem {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: TrayService
        function onUnpinnedItemsChanged() {
            if (TrayService.unpinnedItems.length === 0)
                root.trayOverflowOpen = false
        }
    }
}
