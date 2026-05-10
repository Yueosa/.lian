import QtQuick
import Clavis.Sysmon 1.0

// ============================================================
// SystemView 折线图: 网络/RAM/Load 三标签页, 平滑 Catmull-Rom 曲线 + 滑入动画
// 数据 owner 仍是父级 (history 数组), 本组件只负责: 选 series / 算坐标 / 绘制
// ------------------------------------------------------------
// API 输入:
//   currentTab        : 0=Net  1=RAM  2=Load
//   slideProgress     : 0~1, 新点滑入动画进度
//   revision          : 数据版本号 (父级每次 push 后 +1, 触发重绘)
//   netDownHistory / netUpHistory / ramHistory / load1History / load5History / load15History
//   smoothMaxNet / smoothMaxLoad : 纵坐标动态上限 (RAM 恒为 1)
//   netDownColor / netUpColor / ramLineColor / load1Color / load5Color / load15Color
// ============================================================
Canvas {
    id: chart
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    property int  currentTab: 0
    property real slideProgress: 0
    property int  revision: 0

    property var netDownHistory: []
    property var netUpHistory:   []
    property var ramHistory:     []
    property var load1History:   []
    property var load5History:   []
    property var load15History:  []

    property real smoothMaxNet:  1
    property real smoothMaxLoad: 1

    property color netDownColor: "white"
    property color netUpColor:   "white"
    property color ramLineColor: "white"
    property color load1Color:   "white"
    property color load5Color:   "white"
    property color load15Color:  "white"

    onRevisionChanged:      requestPaint()
    onCurrentTabChanged:    requestPaint()
    onSlideProgressChanged: requestPaint()
    onWidthChanged:         requestPaint()
    onHeightChanged:        requestPaint()

    function _series(slot) {
        if (currentTab === 0) return slot === 0 ? netDownHistory : netUpHistory
        if (currentTab === 1) return slot === 0 ? ramHistory : []
        if (slot === 0) return load1History
        if (slot === 1) return load5History
        return load15History
    }

    function _maxValue() {
        if (currentTab === 0) return Math.max(1, smoothMaxNet)
        if (currentTab === 1) return 1.0
        return Math.max(1, smoothMaxLoad)
    }

    // 构建平滑路径: 把 N 个采样点做带滑动偏移的 Catmull-Rom -> Cubic Bezier
    function _buildPath(ctx, points, maxValue) {
        if (!points || points.length < 2 || width <= 0 || height <= 0) return null
        const pts = SysmonPlugin.buildChartPoints(points, maxValue, width, height, slideProgress)
        if (!pts || pts.length < 2) return null

        const N = pts.length
        const baseY = height - 4
        ctx.beginPath()
        ctx.moveTo(pts[0].x, pts[0].y)
        for (let i = 0; i < N - 1; ++i) {
            const p0 = pts[i - 1] || pts[i]
            const p1 = pts[i]
            const p2 = pts[i + 1]
            const p3 = pts[i + 2] || p2
            ctx.bezierCurveTo(
                p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6,
                p2.x, p2.y)
        }
        return { first: pts[0], last: pts[N - 1], baseY: baseY }
    }

    function _drawSeries(ctx, points, maxValue, color, lineWidth, fillAlpha) {
        const meta = _buildPath(ctx, points, maxValue)
        if (!meta) return
        if (fillAlpha > 0) {
            ctx.lineTo(meta.last.x, meta.baseY)
            ctx.lineTo(meta.first.x, meta.baseY)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, fillAlpha)
            ctx.fill()
            _buildPath(ctx, points, maxValue)  // 重描边路径 (fill 闭合后需重建)
        }
        ctx.lineWidth = lineWidth
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = color
        ctx.stroke()
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        const maxV = _maxValue()
        if (currentTab === 0) {
            _drawSeries(ctx, _series(0), maxV, netDownColor, 2.4, 0.22)
            _drawSeries(ctx, _series(1), maxV, netUpColor,   2.4, 0.16)
        } else if (currentTab === 1) {
            _drawSeries(ctx, _series(0), maxV, ramLineColor, 2.4, 0.22)
        } else {
            _drawSeries(ctx, _series(0), maxV, load1Color,  2.4, 0.16)
            _drawSeries(ctx, _series(1), maxV, load5Color,  2.2, 0.0)
            _drawSeries(ctx, _series(2), maxV, load15Color, 2.0, 0.0)
        }
    }
}
