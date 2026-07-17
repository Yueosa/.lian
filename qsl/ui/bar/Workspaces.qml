// Workspaces — 左上角工作区指示器
// 非活动：灰点 / 有窗短胶囊；活动：缺口甜甜圈慢转
// 切入时加速 + 缺口变大，再缓回稳定
//
// 性能：最多 1 个活动项 ~30fps 轻量 stroke arc；无齿轮、无辉光层

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    property string screenName: ""
    readonly property bool hasMultipleOutputs: Hyprland.monitors.count > 1
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace

    implicitHeight: 36
    implicitWidth: layout.width + 24

    function focusedWorkspaceLabel() {
        const ws = root.focusedWorkspace
        if (!ws)
            return "-"
        if (ws.name !== undefined && ws.name !== null) {
            const digits = String(ws.name).match(/\d+/)
            if (digits && digits.length > 0)
                return digits[0]
        }
        if (ws.id !== undefined && ws.id !== null)
            return String(ws.id)
        if (ws.lastIpcObject && ws.lastIpcObject.id !== undefined && ws.lastIpcObject.id !== null)
            return String(ws.lastIpcObject.id)
        return "-"
    }

    function acceptsOutput(outputName) {
        if (root.screenName === "")
            return true
        if (!root.hasMultipleOutputs && outputName === "")
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
            color: Color.withAlpha(Color.primary, 0.18)

            Text {
                anchors.centerIn: parent
                text: root.focusedWorkspaceLabel()
                color: Color.primary
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.xsm
                font.bold: true
            }
        }

        Repeater {
            model: Hyprland.workspaces

            delegate: Item {
                id: delegateRoot

                readonly property var workspaceRef: modelData
                property bool belongsToScreen: root.acceptsOutput(
                    workspaceRef.monitor ? workspaceRef.monitor.name : "")
                property bool active: workspaceRef.focused
                property bool hasWindows: workspaceRef.toplevels.count > 0
                property bool isHovered: mouseArea.containsMouse

                visible: belongsToScreen
                implicitWidth: !belongsToScreen ? 0 : (active || isHovered ? 20 : 8)
                implicitHeight: !belongsToScreen ? 0 : (active ? 20 : 8)

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Size.anim.slow
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }
                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Size.anim.slow
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.implicitWidth
                    height: 8
                    radius: height / 2
                    visible: !delegateRoot.active
                    color: delegateRoot.hasWindows
                        ? Color.text
                        : (delegateRoot.isHovered ? Color.outlineVariant : Color.surfaceHighest)
                    Behavior on color {
                        ColorAnimation { duration: Size.anim.smooth }
                    }
                }

                Item {
                    id: donut
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    visible: delegateRoot.active

                    property real spinAngle: 0
                    property real gapDeg: 78
                    property real spinDegPerSec: 0
                    readonly property real idleSpeed: 42
                    readonly property real burstSpeed: 420
                    readonly property real idleGap: 78
                    readonly property real burstGap: 155

                    onVisibleChanged: {
                        if (visible)
                            donut.playBurst()
                        else {
                            settleAnim.stop()
                            spinTick.stop()
                            spinDegPerSec = 0
                            gapDeg = idleGap
                        }
                    }

                    function playBurst() {
                        settleAnim.stop()
                        gapDeg = burstGap
                        spinDegPerSec = burstSpeed
                        spinTick.restart()
                        settleAnim.start()
                        ring.requestPaint()
                    }

                    ParallelAnimation {
                        id: settleAnim
                        NumberAnimation {
                            target: donut
                            property: "gapDeg"
                            to: donut.idleGap
                            duration: 1000
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: donut
                            property: "spinDegPerSec"
                            to: donut.idleSpeed
                            duration: 1200
                            easing.type: Easing.OutCubic
                        }
                    }

                    Timer {
                        id: spinTick
                        interval: 33
                        repeat: true
                        running: false
                        onTriggered: {
                            const step = donut.spinDegPerSec * 0.033
                            if (step < 0.05)
                                return
                            donut.spinAngle = (donut.spinAngle + step) % 360
                            ring.requestPaint()
                        }
                    }

                    Canvas {
                        id: ring
                        anchors.fill: parent
                        antialiasing: true

                        onPaint: {
                            const ctx = getContext("2d")
                            const w = width
                            const h = height
                            ctx.clearRect(0, 0, w, h)
                            if (!delegateRoot.active)
                                return

                            const cx = w / 2
                            const cy = h / 2
                            const r = 7.6
                            const lw = 2.6
                            const gap = Math.max(24, donut.gapDeg) * Math.PI / 180
                            const sweep = Math.PI * 2 - gap
                            const start = donut.spinAngle * Math.PI / 180
                            const pr = Color.primary.r
                            const pg = Color.primary.g
                            const pb = Color.primary.b

                            // 实心软核，无外围半透明辉光
                            ctx.beginPath()
                            ctx.arc(cx, cy, 3.4, 0, Math.PI * 2)
                            ctx.fillStyle = Qt.rgba(pr, pg, pb, 1.0)
                            ctx.fill()

                            ctx.beginPath()
                            ctx.lineWidth = lw
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(pr, pg, pb, 1.0)
                            ctx.arc(cx, cy, r, start, start + sweep, false)
                            ctx.stroke()
                        }
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaceRef.activate()
                }
            }
        }
    }
}
