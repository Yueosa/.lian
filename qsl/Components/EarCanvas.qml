// EarCanvas — 凹角耳朵（四分之一圆月牙），岛/栏段与 rail 的衔接件
// corner：弧心所在的内角（决定月牙朝哪边凹）
// 性能：小 Canvas；仅换色时 requestPaint

import QtQuick
import qs.data.state

Canvas {
    id: root

    enum Corner { TopLeft, TopRight, BottomLeft, BottomRight }

    // 兼容旧用法：mirror=false→TopLeft（岛左耳），true→TopRight（岛右耳）
    property bool mirror: false
    property int corner: mirror ? EarCanvas.TopRight : EarCanvas.TopLeft
    property color fillColor: Color.background

    onFillColorChanged: requestPaint()
    onCornerChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // 弧心在内角上，填充对角方向的四分之一圆月牙
    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = root.fillColor
        ctx.beginPath()
        switch (root.corner) {
        case EarCanvas.TopRight:
            // 填左上月牙，弧心右下（岛右耳）
            ctx.moveTo(width, 0)
            ctx.lineTo(0, 0)
            ctx.lineTo(0, height)
            ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false)
            break
        case EarCanvas.BottomLeft:
            // 填右下月牙，弧心左上
            ctx.moveTo(0, height)
            ctx.lineTo(width, height)
            ctx.lineTo(width, 0)
            ctx.arc(0, 0, width, 0, Math.PI * 0.5, false)
            break
        case EarCanvas.BottomRight:
            // 填左下月牙，弧心右上
            ctx.moveTo(width, height)
            ctx.lineTo(0, height)
            ctx.lineTo(0, 0)
            ctx.arc(width, 0, width, Math.PI, Math.PI * 0.5, true)
            break
        case EarCanvas.TopLeft:
        default:
            // 填右上月牙，弧心左下（岛左耳）
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
            break
        }
        ctx.closePath()
        ctx.fill()
    }

    Connections {
        target: Color
        function onBackgroundChanged() { root.requestPaint() }
    }

    Component.onCompleted: requestPaint()
}
