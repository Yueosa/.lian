import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.config

Item {
    id: root

    property string screenName: ""
    readonly property bool hasMultipleOutputs: Hyprland.monitors.count > 1
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace

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

    implicitHeight: 36
    implicitWidth: layout.width + 24

    function acceptsOutput(outputName) {
        if (root.screenName === "")
            return true
        if (!root.hasMultipleOutputs && outputName === "")
            return true
        return outputName === root.screenName
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Colorscheme.background
        radius: height / 2
        visible: false
    }



    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Sizes.spacing.sm

        Rectangle {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            radius: Sizes.rounding.md
            color: Qt.alpha(Colorscheme.primary, 0.18)

            Text {
                anchors.centerIn: parent
                text: root.focusedWorkspaceLabel()
                color: Colorscheme.primary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.xsm
                font.bold: true
            }
        }

        Repeater {
            model: Hyprland.workspaces

            delegate: Item {
                id: delegateRoot

                readonly property var workspaceRef: modelData
                property bool belongsToScreen: root.acceptsOutput(workspaceRef.monitor ? workspaceRef.monitor.name : "")
                property bool active: workspaceRef.focused
                property bool hasWindows: workspaceRef.toplevels.count > 0
                property bool isHovered: mouseArea.containsMouse

                visible: belongsToScreen
                implicitWidth:  !belongsToScreen ? 0 : (active ? 20 : (isHovered ? 20 : 8))
                implicitHeight: !belongsToScreen ? 0 : (active ? 20 : 8)

                Behavior on implicitWidth  { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                // ── 非活跃：普通长条 / 灰点 ──────────────────────────────
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.implicitWidth
                    height: 8
                    radius: height / 2
                    visible: !delegateRoot.active
                    color: delegateRoot.hasWindows ? Colorscheme.on_surface
                         : delegateRoot.isHovered  ? Colorscheme.surface_variant
                         : Colorscheme.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                // ── 活跃：旋转齿轮甜甜圈 ─────────────────────────────────
                Item {
                    id: gearItem
                    anchors.centerIn: parent
                    width: 20; height: 20
                    visible: delegateRoot.active

                    // 齿形展开进度 0→1（active 变化时动画弹出）
                    property real teethProgress: delegateRoot.active ? 1 : 0

                    Behavior on teethProgress {
                        NumberAnimation { duration: 650; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }

                    // 旋转驱动（持续 360°，5s 一圈）
                    property real spinAngle: 0
                    NumberAnimation on spinAngle {
                        from: 0; to: 360
                        duration: 5000
                        loops: Animation.Infinite
                        running: delegateRoot.active
                    }

                    Canvas {
                        id: gearCanvas
                        anchors.fill: parent

                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            if (!delegateRoot.active) return

                            var cx = width  / 2
                            var cy = height / 2

                            // ── 尺寸参数 ────────────────────────────────
                            var maxTeethH = 2.8          // 齿高（满进度时）
                            var rootR     = 6.5          // 齿根圆（donut 外壁）
                            var outerR    = rootR + maxTeethH * gearItem.teethProgress
                            var innerR    = 3.2          // 甜甜圈内孔半径
                            var N         = 8            // 齿数
                            var toothHalf = Math.PI / N * 0.40   // 每齿半角宽
                            var step      = Math.PI * 2 / N
                            var rotRad    = gearItem.spinAngle * Math.PI / 180

                            ctx.save()
                            ctx.translate(cx, cy)
                            ctx.rotate(rotRad)

                            // ── 齿轮外廓路径 ────────────────────────────
                            ctx.beginPath()
                            for (var i = 0; i < N; i++) {
                                var a  = i * step
                                var a0 = a - toothHalf
                                var a1 = a + toothHalf

                                if (i === 0) {
                                    ctx.moveTo(Math.cos(a0) * rootR, Math.sin(a0) * rootR)
                                } else {
                                    // 齿间谷底弧
                                    ctx.arc(0, 0, rootR, (i - 1) * step + toothHalf, a0)
                                }
                                // 上升 → 齿顶弧 → 下降
                                ctx.lineTo(Math.cos(a0) * outerR, Math.sin(a0) * outerR)
                                ctx.arc(0, 0, outerR, a0, a1)
                                ctx.lineTo(Math.cos(a1) * rootR, Math.sin(a1) * rootR)
                            }
                            // 最后一段谷底弧收尾
                            ctx.arc(0, 0, rootR, (N - 1) * step + toothHalf, Math.PI * 2 - toothHalf)
                            ctx.closePath()

                            // ── 甜甜圈内孔（evenodd 减去） ──────────────
                            ctx.moveTo(innerR, 0)
                            ctx.arc(0, 0, innerR, 0, Math.PI * 2, true)

                            // ── 径向渐变填色 ────────────────────────────
                            var grad = ctx.createRadialGradient(
                                -rootR * 0.25, -rootR * 0.25, innerR * 0.4,
                                0, 0, outerR
                            )
                            grad.addColorStop(0.0, Qt.lighter(Colorscheme.primary, 1.7).toString())
                            grad.addColorStop(0.5, Colorscheme.primary.toString())
                            grad.addColorStop(1.0, Qt.darker(Colorscheme.primary, 1.2).toString())
                            ctx.fillStyle = grad
                            ctx.fill("evenodd")

                            ctx.restore()
                        }

                        // 任意驱动属性变化就重绘
                        Connections {
                            target: gearItem
                            function onSpinAngleChanged()   { gearCanvas.requestPaint() }
                            function onTeethProgressChanged() { gearCanvas.requestPaint() }
                        }
                        Connections {
                            target: Colorscheme
                            function onPrimaryChanged()    { gearCanvas.requestPaint() }
                            function onBackgroundChanged() { gearCanvas.requestPaint() }
                        }
                    }

                    // 工作区编号已移除
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
