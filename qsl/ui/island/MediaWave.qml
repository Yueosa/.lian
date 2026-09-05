// MediaWave — 左栏那条波形进度条：cava 喂振幅/频率，Canvas 逐帧重画
//
// 第 10 轮从 MediaPage 摘出来（原文件 785 行，光「频谱驱动」这一段就占 200）。
// 播放头位置和拖动状态**没有**跟着搬：时间标签和那个 200ms 的轮询 Timer 读的是
// 同一份 seekPos，分两份就会各走各的。所以本件对页根只读，拖动结果用信号送回去。
//
// 跟页面的接口：
//   page                —— 回引页根，读 seekPos / trackLength / seeking / visible
//   seekBegan()         —— 按下，页根去置 seeking
//   seekDragged(pos)    —— 拖动中的绝对位置（秒）
//   seekCommitted(frac) —— 松手，比例交回页根，由它调 Media 并回读位置

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Item {
    id: waveRoot

    property Item page: null

    signal seekBegan()
    signal seekDragged(real pos)
    signal seekCommitted(real frac)

    Layout.fillWidth: true
    Layout.preferredHeight: 30

    readonly property real duration: page ? page.trackLength : 0
    readonly property real position: page ? page.seekPos : 0
    readonly property bool seeking: page ? page.seeking : false

    readonly property real progress: duration > 0
        ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property real trackH: 5

    // ---- 频谱驱动 ----
    //
    // 波原来是固定振幅固定周期的正弦，安静段和高潮段长得一模一样。
    // 现在拆两路取 cava：
    //   整体均值 → 振幅 / 频率 / 副波混乱度（"多激烈"）
    //   低频 5 根 → 播放头附近那一鼓（"鼓点顶了一下"）
    // 两个都得平滑：cava 是 30fps 的原始值，直接喂进去是噪声
    // 不是节奏，波形会抖成毛刺
    readonly property real cavaEnergy: {
        const vals = Cava.values
        if (!vals || vals.length < 30)
            return 0
        let s = 0
        for (let i = 0; i < 30; i++)
            s += vals[i] || 0
        return Math.min(1, (s / 30) * 2.2)
    }
    readonly property real cavaBass: {
        const vals = Cava.values
        if (!vals || vals.length < 30)
            return 0
        let s = 0
        for (let i = 0; i < 5; i++)
            s += vals[i] || 0
        return Math.min(1, (s / 5) * 1.3)
    }

    property real energy: Media.playing ? cavaEnergy : 0
    property real bass: Media.playing ? cavaBass : 0

    Behavior on energy {
        SmoothedAnimation { velocity: 2.6 }
    }
    Behavior on bass {
        SmoothedAnimation { velocity: 5.0 }
    }

    // 实测普通段能量约 0.35，系数 6 时振幅只有 3px，看不出"激烈"
    // 的差别，所以拉到 8.5。理论峰值 8.5+3.4 会超过轨道上沿到顶的
    // 12.5，但不靠调参保证——onPaint 里直接钳死（见 yOff）
    readonly property real amp: 1.2 + energy * 8.5
    readonly property real bulgeAmp: bass * 3.4
    readonly property real freq: 0.10 + energy * 0.09
    readonly property real secAmp: 0.3 + energy * 0.5
    readonly property real fadeLen: 24
    readonly property real endFade: 10
    readonly property real bulgeLen: 46
    readonly property real waveBias: 1.3
    readonly property real secFreqMul: 1.5

    property real phase: 0
    property real visualX: width * progress

    Behavior on visualX {
        enabled: !waveRoot.seeking
        SmoothedAnimation { velocity: 500; duration: 400 }
    }

    // 相位自己按帧积分，不用 NumberAnimation 循环。
    // 因为速度要跟着能量变，而改一个**正在跑**的 NumberAnimation
    // 的 duration 会让它当帧跳一下，波形上看就是一道裂口
    readonly property real phaseSpeed: 4.2 + energy * 9.0

    FrameAnimation {
        // 看的是页根的 visible 而不是自己的：本件的 visible 还叠了「有没有
        // 播放器」那一层，页根这个才是「Hub 停在媒体页上没有」
        running: Media.playing && (waveRoot.page ? waveRoot.page.visible : false)
        onTriggered: {
            waveRoot.phase = (waveRoot.phase
                + frameTime * waveRoot.phaseSpeed) % (Math.PI * 2)
        }
    }

    onPhaseChanged: waveCanvas.requestPaint()
    onVisualXChanged: waveCanvas.requestPaint()
    onWidthChanged: waveCanvas.requestPaint()
    // 暂停后 FrameAnimation 停了，靠这两条把波形收平
    onEnergyChanged: waveCanvas.requestPaint()
    onBassChanged: waveCanvas.requestPaint()

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: waveRoot.trackH
        radius: waveRoot.trackH / 2
        color: Color.surfaceContainerHighest
    }

    Canvas {
        id: waveCanvas
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(waveRoot.trackH, waveRoot.visualX)

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.clearRect(0, 0, w, h)

            const trackH = waveRoot.trackH
            const radius = trackH / 2
            const centerY = h / 2
            if (w < radius * 2)
                return

            ctx.beginPath()
            ctx.moveTo(w, centerY + trackH / 2)
            ctx.lineTo(radius, centerY + trackH / 2)
            ctx.arcTo(0, centerY + trackH / 2, 0, centerY, radius)
            ctx.arcTo(0, centerY - trackH / 2, radius, centerY - trackH / 2, radius)

            const freq = waveRoot.freq
            const maxAmp = waveRoot.amp
            const fadeLen = waveRoot.fadeLen
            const endFade = waveRoot.endFade
            const bulgeAmp = waveRoot.bulgeAmp
            const bulgeLen = waveRoot.bulgeLen
            const phase = waveRoot.phase

            // 采样步长。信号里最短的波长来自次波：
            // 2π / (freq_max × secFreqMul) = 2π / (0.19 × 1.5) ≈ 22px。
            // 逐像素等于一个波周期采 22 个点，画一条平滑曲线用不了
            // 那么多——步长 2 之后最密处还有 11 个点，右端 10px 的
            // 收势也还有 5 个，肉眼无差。
            //
            // 而这个循环是**每帧**跑的：一条 400px 的进度条，逐像素
            // 就是每秒 2.4 万次迭代、4.8 万次 sin、2.4 万段路径。
            // 步长 2 直接砍一半。
            //
            // 末点不必正好落在 w 上：endFade 让 yOff 在右端收到 0，
            // 循环外那句 lineTo(w, 轨道上沿) 接的就是同一个高度。
            const step = 2

            for (let x = radius; x <= w; x += step) {
                const leftDist = x - radius
                const rightDist = w - x
                let envelope = 1.0
                if (leftDist < fadeLen)
                    envelope = Math.sin((leftDist / fadeLen) * (Math.PI / 2))
                // 右端只收 10px 而不是 24：播放头那一鼓要露出来，
                // 两端都按 24 淡的话正好把它抹平
                if (rightDist < endFade) {
                    const envRight = Math.sin((rightDist / endFade) * (Math.PI / 2))
                    if (envRight < envelope)
                        envelope = envRight
                }

                // 低频鼓包：只在播放头前 46px 内抬起，二次曲线收尾
                let bulge = 0
                if (bulgeAmp > 0.01 && rightDist < bulgeLen) {
                    const t = 1 - rightDist / bulgeLen
                    bulge = bulgeAmp * t * t * envelope
                }

                let wave1 = Math.sin(x * freq - phase)
                let wave2 = Math.sin(x * freq * waveRoot.secFreqMul - phase * 2.0) * waveRoot.secAmp
                let combined = (wave1 + wave2 + waveRoot.waveBias) / (2 * waveRoot.waveBias)
                if (combined < 0) combined = 0
                if (combined > 1) combined = 1

                // 钳在轨道上沿到容器顶之间，留 1px。振幅是频谱
                // 喂的，上限不该靠"系数调得刚好"来保证
                const headroom = centerY - trackH / 2 - 1
                const yOff = Math.min(headroom,
                    combined * maxAmp * envelope + bulge)
                ctx.lineTo(x, (centerY - trackH / 2) - yOff)
            }

            ctx.lineTo(w, centerY - trackH / 2)
            ctx.lineTo(w, centerY + trackH / 2)
            ctx.closePath()
            ctx.fillStyle = String(Color.primary)
            ctx.fill()
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        // 比例按本 MouseArea 的宽算（它比轨道左右各宽 6px），页根照单全收
        onPressed: waveRoot.seekBegan()
        onReleased: (mouse) => waveRoot.seekCommitted(mouse.x / width)
        onPositionChanged: (mouse) => {
            if (!pressed || waveRoot.duration <= 0)
                return
            waveRoot.seekDragged(
                Math.max(0, Math.min(1, mouse.x / width)) * waveRoot.duration)
        }
    }
}
