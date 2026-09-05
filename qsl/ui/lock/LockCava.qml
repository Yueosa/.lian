// LockCava — 锁屏下半屏的频谱背景。是背景，不是控件：不接受点击，
// 没媒体时也留一层很淡的（0.16），屏幕不至于下半片全黑。
//
// 第 10 轮从 LockContent 摘出来。重绘的订阅（Cava.onValuesChanged）跟着搬过来了
// ——原先它挂在页根、隔着 700 行去 requestPaint 这块画布。

import QtQuick
import qs.data.state
import qs.data.service

Canvas {
    id: cavaCanvas

    // 有媒体才显著；没媒体留一层底噪
    property bool hasMedia: false
    // 页根的 cava 引用计数状态，决定要不要订阅重绘
    property bool cavaHeld: false

    height: parent.height * 0.46
    opacity: hasMedia ? 0.5 : 0.16
    z: 0

    Connections {
        target: Cava
        enabled: cavaCanvas.cavaHeld
        function onValuesChanged() { cavaCanvas.requestPaint() }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        const w = width
        const h = height
        ctx.reset()
        const vals = Cava.values || []
        const n = 30
        const gap = 3
        const barW = Math.max(2, (w - gap * (n - 1)) / n)
        const c0 = String(Color.primary)
        const c1 = String(Color.inversePrimary)
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, Number(vals[i]) || 0))
            const bh = Math.max(4, v * h)
            const x = i * (barW + gap)
            ctx.globalAlpha = 0.2 + 0.8 * v
            const g = ctx.createLinearGradient(0, h, 0, h - bh)
            g.addColorStop(0, c0)
            g.addColorStop(1, c1)
            ctx.fillStyle = g
            ctx.fillRect(x, h - bh, barW, bh)
        }
    }
    Behavior on opacity { Anim { type: Anim.Effects } }
}
