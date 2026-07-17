// Bar — 顶部状态栏
// 左：工作区 + 窗口名；右：Tray + WiFi/BT/Audio 芯片
//
// 性能：无 MultiEffect 阴影、无 gooey；芯片无点击开栏

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.data.state

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData

        anchors {
            left: true
            top: true
            right: true
        }
        color: "transparent"

        readonly property real barHeight: 46

        implicitHeight: barHeight
        exclusiveZone: barHeight

        WlrLayershell.namespace: "qsl-bar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Normal

        Item {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: barWindow.barHeight

            RowLayout {
                anchors {
                    left: parent.left
                    leftMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: Size.spacing.md

                Workspaces {
                    screenName: barWindow.screen.name
                }

                ActiveWindow {}
            }

            RowLayout {
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                spacing: Size.spacing.sm

                Tray {}
                StatusChips {}
            }
        }
    }
}
