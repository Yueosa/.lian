// EarCanvas — 灵动岛左右耳朵（四分之一圆凹角）
// 性能：16×16 Canvas；仅换色时 requestPaint

import QtQuick
import qs.data.state

Canvas {
    id: root

    // false = 左耳；true = 右耳
    property bool mirror: false
    property color fillColor: Color.background

    onFillColorChanged: requestPaint()
    onMirrorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = root.fillColor
        ctx.beginPath()
        if (root.mirror) {
            ctx.moveTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.lineTo(0, height)
            ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
        } else {
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
        }
        ctx.fill()
    }

    Connections {
        target: Color
        function onBackgroundChanged() { root.requestPaint() }
        function onShadowChanged() { root.requestPaint() }
    }

    Component.onCompleted: requestPaint()
}
