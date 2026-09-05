// MediaPage — 左封面+操控，右歌词通高，cava 压在歌词底下
//
// 布局取舍（第 8 轮第二版）：
//   · 封面 232 见方，左边距 24。上一版封面只有 188×168、左边距 10，
//     一条 800 宽的页面里左栏占不到四分之一，右边歌词一个人占 560——
//     两栏的权重差得太远，看着像歌词页附带了个小播放器。
//   · cava 从封面右下角挪到歌词下面通宽一条。压在封面上时它既盖住画面
//     又只有 14 根柱子；下面这条能铺 30 根，宽度还跟歌词对齐。
//   · 播放器选择器提到整页右上角。它原来是左栏中间一条药丸，一展开就
//     盖住封面，而"换播放器"是低频操作，不该占正文位置。
//
// 高度预算（mediaHeight 448，减上下 margins 32 = 416 可用）：
//   封面 232 + 标题 19 + 艺人 16 + 进度 30 + 时间 15 + 控件 38
//   + 六段间距 48 = 398，剩 18 给中间那个 filler 撑开
//   进度条要 30 而不是 22：波形振幅跟着频谱最高能抬 10.8px，22 会顶破
//
// 性能：随 Loader 销毁；Cava.acquire/release；无 FastBlur / 无圆形频谱

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 取值全部走 Media 的公开面。这里只留「没播放器时显示什么」——那是呈现决定，
    // 锁屏同一份数据显示的是空串
    readonly property bool hasPlayer: Media.hasActive
    readonly property string trackTitle: Media.trackTitle || "未知曲目"
    readonly property string trackArtist: Media.hasActive
        ? (Media.trackArtist || "未知艺人")
        : ""
    readonly property real trackLength: Media.trackLength

    property real seekPos: 0
    property bool seeking: false
    property bool playerExpanded: false

    function centerLyric() {
        if (Lyrics.currentIndex >= 0)
            lyricsList.positionViewAtIndex(Lyrics.currentIndex, ListView.Center)
    }

    Component.onCompleted: {
        Cava.acquire()
        Lyrics.acquire()
        Media.syncLyrics()
    }
    Component.onDestruction: {
        Cava.release()
        Lyrics.release()
    }

    // 换播放器或换曲目都由 Media.trackChanged 一个信号覆盖，不必再把 Media.active
    // 当 Connections 的 target 自己盯一遍
    Connections {
        target: Media
        function onTrackChanged() { Media.syncLyrics() }
        function onActiveChanged() { root.playerExpanded = false }
    }

    Timer {
        interval: 200
        running: root.hasPlayer
        repeat: true
        onTriggered: {
            if (!root.seeking)
                root.seekPos = Media.position()
            if (Media.isMusic)
                Lyrics.syncPosition(root.seekPos)
        }
    }

    QslStagger { id: stagger }
    function playEnter() { stagger.restart() }

    Column {
        anchors.centerIn: parent
        spacing: Size.spacing.md
        visible: !root.hasPlayer

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\uf001"
            color: Color.textMuted
            font.family: Size.fontMono
            font.pixelSize: 48
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "没有媒体播放器"
            color: Color.textMuted
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.titleMedium
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        anchors.leftMargin: 24
        anchors.rightMargin: 16
        spacing: 24
        visible: root.hasPlayer

        ColumnLayout {
            Layout.preferredWidth: 232
            Layout.maximumWidth: 232
            Layout.fillHeight: true
            spacing: 8
            opacity: stagger.shown(0) ? 1 : 0
            transform: Translate {
                y: stagger.shown(0) ? 0 : 12
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }

            Rectangle {
                id: artBox
                Layout.preferredWidth: 232
                Layout.preferredHeight: 232
                radius: Size.rounding.xl
                color: Color.surfaceContainerHighest

                scale: Media.playing ? 1.0 : 0.95
                Behavior on scale {
                    Anim { type: Anim.Spatial }
                }

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: Media.trackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(280, 280)
                    cache: false
                    visible: status === Image.Ready

                    // 圆角裁图走遮罩：clip 只裁矩形包围盒，圆角会被图盖回方的
                    layer.enabled: status === Image.Ready
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: Item {
                            width: artImg.width
                            height: artImg.height
                            Rectangle {
                                anchors.fill: parent
                                radius: artBox.radius
                                color: "#000000"
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !Media.trackArtUrl.length
                    text: Media.activeIdentityIcon
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: 56
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.trackTitle
                color: Color.backgroundText
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.titleSmall
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.trackArtist
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodySmall
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 30

                Item {
                    id: waveRoot
                    anchors.fill: parent

                    readonly property real progress: root.trackLength > 0
                        ? Math.max(0, Math.min(1, root.seekPos / root.trackLength)) : 0
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
                        enabled: !root.seeking
                        SmoothedAnimation { velocity: 500; duration: 400 }
                    }

                    // 相位自己按帧积分，不用 NumberAnimation 循环。
                    // 因为速度要跟着能量变，而改一个**正在跑**的 NumberAnimation
                    // 的 duration 会让它当帧跳一下，波形上看就是一道裂口
                    readonly property real phaseSpeed: 4.2 + energy * 9.0

                    FrameAnimation {
                        running: Media.playing && root.visible
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
                        onPressed: root.seeking = true
                        onReleased: (mouse) => {
                            if (root.trackLength > 0) {
                                Media.seekFraction(mouse.x / width)
                                root.seekPos = Media.position()
                            }
                            root.seeking = false
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed || root.trackLength <= 0)
                                return
                            root.seekPos = Math.max(0, Math.min(1, mouse.x / width)) * root.trackLength
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Media.formatTime(root.seekPos)
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.labelSmall
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Media.formatTime(root.trackLength)
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.labelSmall
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                MediaCtrlBtn {
                    glyph: "\uf074"
                    active: Media.shuffleOn
                    enabled: Media.shuffleOk
                    onTriggered: Media.toggleShuffle()
                }
                MediaCtrlBtn {
                    glyph: "\uf048"
                    onTriggered: Media.previousTrack()
                }
                MediaCtrlBtn {
                    glyph: Media.playing ? "\uf04c" : "\uf04b"
                    primary: true
                    onTriggered: Media.playPause()
                }
                MediaCtrlBtn {
                    glyph: "\uf051"
                    onTriggered: Media.nextTrack()
                }
                MediaCtrlBtn {
                    glyph: Media.loopOne ? "\uf021" : "\uf079"
                    active: Media.loopOn
                    enabled: Media.loopOk
                    onTriggered: Media.cycleLoop()
                }
            }
        }

        // ---- 右栏：歌词通高 + 底下一条 cava ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            opacity: stagger.shown(1) ? 1 : 0
            transform: Translate {
                y: stagger.shown(1) ? 0 : 12
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // 让开右上角那颗播放器药丸。歌词是垂直居中的，这里只是把
                // 整块往下压 34，中心线跟着挪 17px，看不出来；不让的话
                // 顶上那句（虽然已经淡掉了）会被药丸切一刀
                Layout.topMargin: 34
                clip: true

                ListView {
                    id: lyricsList
                    anchors.fill: parent
                    clip: true
                    reuseItems: true
                    spacing: 12
                    model: Lyrics.lines
                    currentIndex: Lyrics.currentIndex
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 28
                    preferredHighlightEnd: height / 2 + 28
                    highlightMoveDuration: Size.anim.durFast
                    highlightMoveVelocity: -1

                    // 首尾各垫半屏，否则第一句和最后一句永远居不了中：
                    // contentY 到 0 就停了，StrictlyEnforceRange 也拉不动它。
                    // 播放器停在 0:00 时当前句是第一句，屏上就是贴着顶——
                    // 看着像歌词没对齐，其实是没地方可滚
                    topMargin: Math.max(0, height / 2 - 28)
                    bottomMargin: Math.max(0, height / 2 - 28)

                    Connections {
                        target: Lyrics
                        function onCurrentIndexChanged() {
                            root.centerLyric()
                        }
                        function onLinesChanged() {
                            Qt.callLater(root.centerLyric)
                        }
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: lyricsList.width
                        // 行高按焦点字号算死。字号一变 Text 会重新折行，
                        // 动画中途行数跳一下就是闪。所以折行永远按 26px 排，
                        // 焦点只动 scale / 颜色 / 透明度
                        height: lyricText.implicitHeight

                        readonly property bool isCurrent: index === Lyrics.currentIndex

                        Text {
                            id: lyricText
                            width: parent.width
                            text: modelData.text || ""
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            color: parent.isCurrent ? Color.primary : Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            opacity: parent.isCurrent ? 1.0 : 0.42
                            // 14/26 ≈ 0.54 是旧的字号比；略抬到 0.72，非焦点
                            // 还能读，焦点放大又不至于把邻居挤出节奏
                            scale: parent.isCurrent ? 1.0 : 0.72
                            transformOrigin: Item.Center

                            Behavior on opacity {
                                Anim { type: Anim.Effects }
                            }
                            Behavior on scale {
                                Anim { type: Anim.Spatial }
                            }
                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 44
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Color.background }
                        GradientStop { position: 1.0; color: Color.withAlpha(Color.background, 0) }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Color.withAlpha(Color.background, 0) }
                        GradientStop { position: 1.0; color: Color.background }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Lyrics.loading && Lyrics.lines.length === 0
                    text: "搜寻歌词…"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.labelLarge
                }
            }

            // cava 通宽一条压在歌词底下。柱宽按可用宽反算，30 根铺满
            Item {
                id: cavaStrip
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 40
                Layout.maximumHeight: 40

                readonly property int bars: 30
                readonly property real gap: 6
                readonly property real barW:
                    Math.max(2, (width - (bars - 1) * gap) / bars)

                Row {
                    anchors.fill: parent
                    spacing: cavaStrip.gap

                    Repeater {
                        model: cavaStrip.bars

                        Rectangle {
                            required property int index
                            width: cavaStrip.barW
                            anchors.bottom: parent.bottom
                            height: {
                                const vals = Cava.values
                                if (!vals || vals.length < cavaStrip.bars)
                                    return 3
                                return 3 + (vals[index] || 0) * (cavaStrip.height - 3)
                            }
                            radius: 3
                            color: Color.withAlpha(Color.primary, 0.85)

                            Behavior on height {
                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 播放器选择器：整页右上角，浮在歌词上面 ----
    // 换播放器是低频操作，不该在左栏正文里占一条位置；收起时只是一颗药丸，
    // 展开才往下掉一列
    Item {
        id: playerPicker
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        width: 184
        height: 28
        z: 50
        visible: root.hasPlayer
        opacity: stagger.shown(2) ? 1 : 0
        Behavior on opacity { Anim { type: Anim.EffectsSlow } }

        Rectangle {
            id: pickerChip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            radius: Size.rounding.full
            color: Color.surfaceContainerHigh

            Behavior on color {
                CAnim {}
            }

            // 展开时保持强调态：「这一列是开着的」不随鼠标走
            QslStateLayer {
                source: playerChipMa
                tint: Color.primary
                accent: true
                selected: root.playerExpanded
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: Media.activeIdentityIcon
                    color: Color.primary
                    font.family: Size.fontMono
                    font.pixelSize: Size.iconSize.sm
                }
                Text {
                    Layout.fillWidth: true
                    text: Media.activeIdentity
                    color: Color.primary
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.labelSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: root.playerExpanded ? "\uf077" : "\uf078"
                    color: Color.primary
                    font.family: Size.fontMono
                    font.pixelSize: Size.iconSize.xs
                }
            }

            MouseArea {
                id: playerChipMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playerExpanded = !root.playerExpanded
            }
        }

        Column {
            anchors.top: pickerChip.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2
            visible: root.playerExpanded

            Repeater {
                model: Media.list

                Rectangle {
                    required property var modelData
                    width: playerPicker.width
                    height: 28
                    radius: Size.rounding.sm
                    // 底色必须是不透明的：这一列浮在歌词上面，半透明会透字
                    color: modelData === Media.active
                        ? Color.primary
                        : Color.surfaceContainerHigh

                    // 当前项已经是实心 primary，再叠一层只会把上面的字糊掉
                    QslStateLayer {
                        source: rowMa
                        active: modelData !== Media.active
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        text: Media.getIdentityIcon(modelData) + "  " + Media.getIdentity(modelData)
                        color: modelData === Media.active ? Color.primaryText : Color.backgroundText
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.labelSmall
                        font.bold: modelData === Media.active
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // 选播放器会改 Media.active，歌词由 trackChanged 自动跟上
                        onClicked: {
                            Media.selectPlayer(modelData)
                            root.playerExpanded = false
                        }
                    }
                }
            }
        }
    }

    component MediaCtrlBtn: Rectangle {
        id: btn
        property string glyph: ""
        property bool active: false
        property bool primary: false
        signal triggered()

        width: primary ? 42 : 34
        height: primary ? 42 : 34
        radius: width / 2
        color: {
            if (primary)
                return Color.primary
            if (active)
                return Color.withAlpha(Color.primary, Color.state.selected)
            return Color.surfaceContainerHigh
        }
        opacity: enabled ? 1 : 0.35

        // 主键底色是实心 primary，叠加得用 on-primary 才看得见
        QslStateLayer {
            source: ma
            active: btn.enabled
            tint: btn.primary ? Color.primaryText : Color.text
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: primary ? Color.primaryText : (active ? Color.primary : Color.backgroundText)
            font.family: Size.fontMono
            font.pixelSize: primary ? Size.iconSize.lg : Size.iconSize.md
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
