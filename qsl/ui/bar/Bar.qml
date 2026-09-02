// Bar — 顶部分段栏（单窗口全宽）+ 三边 rail
// 一个全宽窗口画左右两段 + 段外端两颗衔接耳；段宽直接绑内容宽度，
// 平滑性由内容自己的动画提供（段再加 Behavior 就是双重动画，耳/段会慢内容一拍）
// 必须全宽锚定：Hyprland 对角锚定的 layer 面忽略 exclusiveZone
// exclusiveZone 取灵动岛收起高度：窗口不能进岛的区域（段本身只有 36）
//
// 性能：无 MultiEffect 阴影、无 gooey；SysMonitor 复用 Sysmon 摘要

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWin
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            color: "transparent"

            // 段高对齐灵动岛收起高：顶框成一条直线，段下不留缺口
            readonly property int segHeight: Size.island.collapsedH
            readonly property int earSize: 14
            readonly property int sideMargin: 10

            implicitHeight: segHeight
            exclusiveZone: Size.island.collapsedH

            // RightBar 悬停意图：chip 展开即锁存（各自的 onIsHoveredChanged），
            // 鼠标完全离开右段 1s 后统一回收；在段内移动不回收。
            // 判定取并集：底层面管缝隙，chip 管自己——
            // 单独用底层面时，停在 chip 上 hover 事件被上层吃掉会误判离开
            readonly property bool rightBarHovered: rightBarMa.containsMouse
                || sysMon.isHovered || statusChips.anyHovered || tray.hovered

            function collapseRightChips() {
                sysMon.expanded = false
                statusChips.collapseAll()
                tray.collapse()
            }

            onRightBarHoveredChanged: {
                if (rightBarHovered)
                    rightCollapseTimer.stop()
                else
                    rightCollapseTimer.restart()
            }

            Timer {
                id: rightCollapseTimer
                interval: 1000
                onTriggered: barWin.collapseRightChips()
            }

            WlrLayershell.namespace: "qsl-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Normal

            // 左段：工作区 + 窗口名；宽度跟随内容，无过冲滑行
            Rectangle {
                id: leftSeg
                x: 0
                y: 0
                width: Math.max(200, leftHolder.implicitWidth + barWin.sideMargin * 2)
                height: barWin.segHeight
                color: Color.background
                bottomRightRadius: 22
                clip: true

                RowLayout {
                    id: leftHolder
                    anchors.left: parent.left
                    anchors.leftMargin: barWin.sideMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Size.spacing.md

                    Workspaces {
                        screenName: barWin.screen.name
                    }
                    ActiveWindow {}
                }
            }

            // 右段：Tray + SysMonitor + StatusChips
            Rectangle {
                id: rightSeg
                anchors.right: parent.right
                y: 0
                width: Math.max(200, rightHolder.implicitWidth + barWin.sideMargin * 2)
                height: barWin.segHeight
                color: Color.background
                bottomLeftRadius: 22
                clip: true

                // 右段整体悬停面：z:-1 不抢图标事件，只测在不在栏内
                MouseArea {
                    id: rightBarMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    z: -1
                }

                RowLayout {
                    id: rightHolder
                    anchors.right: parent.right
                    anchors.rightMargin: barWin.sideMargin
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Size.spacing.sm

                    SysMonitor { id: sysMon }
                    StatusChips { id: statusChips }
                    Tray {
                        id: tray
                        screen: barWin.screen
                    }
                }
            }

            // 左段外端 × 顶边 衔接耳
            EarCanvas {
                x: leftSeg.width
                y: 0
                width: barWin.earSize
                height: barWin.earSize
                corner: EarCanvas.TopRight
            }

            // 右段外端 × 顶边 衔接耳
            EarCanvas {
                x: barWin.width - rightSeg.width - barWin.earSize
                y: 0
                width: barWin.earSize
                height: barWin.earSize
                corner: EarCanvas.TopLeft
            }
        }
    }

    Rails {}
}
