// Workspaces — 左上角工作区指示器
// 一个胶囊讲完四态，只变宽度和颜色：空工作区 8px 暗圆点，有窗亮一档，
// 悬停拉长到 20，活动的那个上主题色
//
// 性能：全静态图元，没有常驻动画。活动态原本是一张一直在转的 Canvas 甜甜圈，
// 光它一个就值 10.6 个百分点的 CPU（空闲 11.80% → 0.28%）——因为只要场景里
// 有动画没停，Qt Quick 的渲染循环就不休眠，整条 bar 按 vsync 陪着重绘。
// 详见 plan-notes「常驻动画」一节。

import QtQuick
import QtQuick.Layouts
import qs.data.service
import qs.data.state

Item {
    id: root

    property string screenName: ""

    implicitHeight: 36
    implicitWidth: layout.width + 24

    function acceptsOutput(outputName) {
        if (root.screenName === "")
            return true
        if (!HyprService.multiMonitor && outputName === "")
            return true
        return outputName === root.screenName
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.background
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Size.spacing.sm

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: Size.rounding.md
            color: Color.primaryContainer

            Text {
                anchors.centerIn: parent
                text: HyprService.workspaceLabel(HyprService.focusedWorkspace)
                color: Color.primaryContainerText
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.labelSmall
                font.bold: true
            }
        }

        Repeater {
            model: HyprService.workspaces

            delegate: Item {
                id: delegateRoot

                readonly property var workspaceRef: modelData
                property bool belongsToScreen: root.acceptsOutput(
                    HyprService.workspaceMonitorName(workspaceRef))
                property bool active: HyprService.workspaceFocused(workspaceRef)
                property bool hasWindows: HyprService.workspaceWindowCount(workspaceRef) > 0
                property bool isHovered: mouseArea.containsMouse

                visible: belongsToScreen
                implicitWidth: !belongsToScreen ? 0 : (active || isHovered ? 20 : 8)
                implicitHeight: !belongsToScreen ? 0 : 8

                Behavior on implicitWidth {
                    Anim {}
                }
                Behavior on implicitHeight {
                    Anim {}
                }

                // 一个矩形讲完四个状态，靠宽度和颜色区分——活动态原本是另起炉灶的
                // 一张 Canvas 甜甜圈，形状、渲染路径、视觉语言都和其余三态对不上
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.implicitWidth
                    height: 8
                    radius: height / 2
                    color: delegateRoot.active
                        ? Color.primary
                        : (delegateRoot.hasWindows
                            ? Color.text
                            : (delegateRoot.isHovered ? Color.outlineVariant : Color.surfaceContainerHighest))
                    Behavior on color {
                        CAnim {}
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprService.activateWorkspace(delegateRoot.workspaceRef)
                }
            }
        }
    }
}
