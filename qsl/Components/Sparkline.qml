// Sparkline — 迷你趋势曲线
//
// 性能约束（重要）：
//   - 只在 values 变化时 requestPaint，跟着 sysmond 的 1–3s 采样走，不是逐帧动画。
//     一分钟内重绘 20–60 次，每次画 60 个点，开销可忽略。
//   - renderTarget 用默认的 Canvas.Image（软件绘制后上传纹理），不用
//     FramebufferObject：后者每个实例都要占一块 GPU 离屏缓冲，
//     而这里只有几十像素高，软件路径更省。
//   - 不开 antialiasing 之外的任何特效，无阴影、无渐变蒙版。
//
// maxValue > 0 时为固定量程（如百分比用 100）；
// maxValue <= 0 时按 values 的峰值自适应，并以 minSpan 兜底，
// 避免全是噪声时被放大成大波浪。

import QtQuick
import qs.data.state

Canvas {
    id: root

    property var values: []
    property real maxValue: 100
    property real minSpan: 1
    property color lineColor: Color.primary
    property real lineWidth: 1.5
    // 曲线下方的淡色填充，帮助在深色背景上看清趋势
    property bool fillArea: true
    property real fillOpacity: 0.18
    // 外部可直接给定量程（如网速上下行共用同一峰值），省得各画各的
    property real overrideMax: 0

    // 圆角底板由 Canvas 自己画并 clip：
    // Item.clip 只能裁矩形，用外层圆角 Rectangle 兜不住填充区的下面两个角。
    property real cornerRadius: 0
    property color backgroundColor: "transparent"

    antialiasing: true

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onOverrideMaxChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onBackgroundColorChanged: requestPaint()

    function _roundedPath(ctx, x, y, w, h, r) {
        const rr = Math.min(r, w / 2, h / 2)
        ctx.beginPath()
        ctx.moveTo(x + rr, y)
        ctx.lineTo(x + w - rr, y)
        ctx.arcTo(x + w, y, x + w, y + rr, rr)
        ctx.lineTo(x + w, y + h - rr)
        ctx.arcTo(x + w, y + h, x + w - rr, y + h, rr)
        ctx.lineTo(x + rr, y + h)
        ctx.arcTo(x, y + h, x, y + h - rr, rr)
        ctx.lineTo(x, y + rr)
        ctx.arcTo(x, y, x + rr, y, rr)
        ctx.closePath()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()

        if (width <= 0 || height <= 0)
            return

        // 底板 + 裁剪要在没数据时也生效，否则空曲线会露出方角空洞
        if (root.cornerRadius > 0) {
            root._roundedPath(ctx, 0, 0, width, height, root.cornerRadius)
            if (Qt.colorEqual(root.backgroundColor, "transparent") === false) {
                ctx.fillStyle = root.backgroundColor
                ctx.fill()
            }
            ctx.clip()
        } else if (Qt.colorEqual(root.backgroundColor, "transparent") === false) {
            ctx.fillStyle = root.backgroundColor
            ctx.fillRect(0, 0, width, height)
        }

        const v = root.values || []
        const n = v.length
        if (n < 2)
            return

        let top = root.overrideMax > 0
            ? root.overrideMax
            : root.maxValue
        if (top <= 0) {
            top = root.minSpan
            for (let i = 0; i < n; i++) {
                if (v[i] > top)
                    top = v[i]
            }
        }
        if (top <= 0)
            return

        // 上下各留 1px，否则峰值贴边会被线宽切掉一半
        const pad = Math.min(1, height / 4)
        const h = height - pad * 2
        const stepX = width / (n - 1)

        function yOf(val) {
            const f = Math.max(0, Math.min(1, val / top))
            return pad + h - f * h
        }

        ctx.beginPath()
        ctx.moveTo(0, yOf(v[0]))
        for (let i = 1; i < n; i++)
            ctx.lineTo(i * stepX, yOf(v[i]))

        if (root.fillArea) {
            // 复用同一条路径闭合成面积，不重新走一遍点
            ctx.lineTo((n - 1) * stepX, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g,
                                    root.lineColor.b, root.fillOpacity)
            ctx.fill()

            // 面积填完后重新描线，避免闭合边被一起描出来
            ctx.beginPath()
            ctx.moveTo(0, yOf(v[0]))
            for (let i = 1; i < n; i++)
                ctx.lineTo(i * stepX, yOf(v[i]))
        }

        ctx.strokeStyle = root.lineColor
        ctx.lineWidth = root.lineWidth
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
    }
}
