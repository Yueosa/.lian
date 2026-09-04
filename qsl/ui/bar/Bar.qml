// Bar — 顶部分段栏（窗内 item，plan 第 6 轮起不再自带窗口）
// 左右两段 + 段外端两颗衔接耳；段宽直接绑内容宽度，
// 平滑性由内容自己的动画提供（段再加 Behavior 就是双重动画，耳/段会慢内容一拍）
//
// 合并前它是一个全宽 PanelWindow，自己声明 exclusiveZone。现在画在 FrameWindow
// 里，撑位交给 ui/frame/Exclusions.qml 的顶边小窗——一个 surface 只能声明一个
// 独占区，而框要留四条边。
//
// 性能：无 MultiEffect 阴影、无 gooey；SysMonitor 复用 Sysmon 摘要

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state

Item {
    id: root

    // Workspaces / Tray 要按屏取数据
    required property var screen

    // 给 FrameWindow 算 mask 用：只有这两段吃点击，段间空档穿透到桌面
    readonly property Item leftSeg: leftSegment
    readonly property Item rightSeg: rightSegment

    readonly property int segHeight: height
    readonly property int earSize: 14
    readonly property int sideMargin: 10

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
        onTriggered: root.collapseRightChips()
    }

    // 左段：工作区 + 窗口名；宽度跟随内容，无过冲滑行
    Rectangle {
        id: leftSegment
        x: 0
        y: 0
        width: Math.max(200, leftHolder.implicitWidth + root.sideMargin * 2)
        height: root.segHeight
        color: Color.background
        bottomRightRadius: 22
        clip: true

        RowLayout {
            id: leftHolder
            anchors.left: parent.left
            anchors.leftMargin: root.sideMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Size.spacing.md

            Workspaces {
                screenName: root.screen.name
            }
            ActiveWindow {}
        }
    }

    // 右段：Tray + SysMonitor + StatusChips
    Rectangle {
        id: rightSegment
        anchors.right: parent.right
        y: 0
        width: Math.max(200, rightHolder.implicitWidth + root.sideMargin * 2)
        height: root.segHeight
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
            anchors.rightMargin: root.sideMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Size.spacing.sm

            SysMonitor { id: sysMon }
            StatusChips { id: statusChips }
            Tray {
                id: tray
                screen: root.screen
            }
        }
    }

    // 左段外端 × 顶边 衔接耳
    EarCanvas {
        x: leftSegment.width
        y: 0
        width: root.earSize
        height: root.earSize
        corner: EarCanvas.TopRight
    }

    // 右段外端 × 顶边 衔接耳
    EarCanvas {
        x: root.width - rightSegment.width - root.earSize
        y: 0
        width: root.earSize
        height: root.earSize
        corner: EarCanvas.TopLeft
    }
}
