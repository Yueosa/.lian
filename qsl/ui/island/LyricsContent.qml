// LyricsContent — 一级岛歌词胶囊（封面 + 滚动歌词 + 6 柱 cava）
// 数据：Lyrics / Cava / Media；悬停还原时钟由 IslandShell 处理
// 性能：仅 active 时 Cava.acquire；频谱 ~33ms；无 FastBlur

import QtQuick
import qs.data.state
import qs.data.service

Item {
    id: lyricsRoot

    readonly property var player: Media.active
    readonly property bool isMusic: Media.isMusicPlayer(player)
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

    readonly property int pad: 12
    readonly property int coverSize: 26
    readonly property int spectrumW: 22
    readonly property int gap: 10
    readonly property int rowH: Math.max(28, height - 4)

    // 动态宽度：chrome 固定 + 歌词区随当前行变（对齐旧 qs）
    readonly property int chromeW: pad * 2 + coverSize + spectrumW + gap * 2
    readonly property int defaultTextW: 170
    readonly property int maxTextW: 560
    property int textW: defaultTextW

    implicitWidth: chromeW + textW
    implicitHeight: Size.island.lyricsH

    property var smoothValues: [0, 0, 0, 0, 0, 0]
    // toast/悬停切回时 bump，强制当前行重算跑马灯（避免卡在半动画）
    property int marqueeEpoch: 0

    function updateTextWidth(implicitTextW) {
        const raw = Number(implicitTextW) || 0
        // 排版未就绪时别把已算好的岛宽压回去
        if (raw <= 0)
            return
        const w = Math.max(
            lyricsRoot.defaultTextW,
            Math.min(Math.ceil(raw) + 16, lyricsRoot.maxTextW)
        )
        if (w !== lyricsRoot.textW)
            lyricsRoot.textW = w
    }

    function kickVisible() {
        if (lyricsRoot.player)
            Lyrics.syncPosition(Number(lyricsRoot.player.position) || 0)
        const i = Lyrics.currentIndex
        if (i >= 0)
            lyricsView.positionViewAtIndex(i, ListView.Beginning)
        // 等岛宽 morph（350ms）后再重算居中/跑马灯
        remountTimer.restart()
    }

    Timer {
        id: remountTimer
        interval: 380
        repeat: false
        onTriggered: {
            if (lyricsRoot.visible)
                marqueeEpoch++
        }
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(kickVisible)
        else
            remountTimer.stop()
    }

    Component.onCompleted: {
        Cava.acquire()
        Lyrics.acquire()
        refresh()
    }
    Component.onDestruction: {
        Cava.release()
        Lyrics.release()
    }

    function refresh() {
        if (!player) {
            // 不 clear 全局缓存：Hub Media 可能仍在用
            Lyrics.setPlaceholder("")
            lyricsRoot.textW = lyricsRoot.defaultTextW
            return
        }
        if (!isMusic) {
            Lyrics.setPlaceholder(player.trackTitle || "正在播放")
            return
        }
        Lyrics.fetch(
            player.trackTitle || "",
            player.trackArtist || "",
            Media.getIdentity(player),
            Media.trackUrl(player)
        )
    }

    Connections {
        target: Media
        function onActiveChanged() { lyricsRoot.refresh() }
    }
    Connections {
        target: lyricsRoot.player
        enabled: !!lyricsRoot.player
        function onTrackTitleChanged() { lyricsRoot.refresh() }
        function onTrackArtistChanged() { lyricsRoot.refresh() }
        function onPositionChanged() {
            if (lyricsRoot.player)
                Lyrics.syncPosition(Number(lyricsRoot.player.position) || 0)
        }
    }

    Timer {
        interval: 100
        running: lyricsRoot.visible && !!lyricsRoot.player && Lyrics.lines.length > 1
        repeat: true
        onTriggered: {
            if (lyricsRoot.player)
                Lyrics.syncPosition(Number(lyricsRoot.player.position) || 0)
        }
    }

    // ---- 封面 ----
    Item {
        id: coverBox
        anchors.left: parent.left
        anchors.leftMargin: lyricsRoot.pad
        anchors.verticalCenter: parent.verticalCenter
        width: lyricsRoot.coverSize
        height: lyricsRoot.coverSize

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: Color.surfaceHighest
            clip: true

            Image {
                anchors.fill: parent
                source: lyricsRoot.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(64, 64)
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: !lyricsRoot.artUrl.length
                text: "\uf001"
                color: Color.textMuted
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.sm
            }
        }
    }

    // ---- 频谱（6 柱，对称聚合；值域 0–1）----
    Item {
        id: spectrumBox
        anchors.right: parent.right
        anchors.rightMargin: lyricsRoot.pad
        anchors.verticalCenter: parent.verticalCenter
        width: lyricsRoot.spectrumW
        height: 16

        Timer {
            interval: 33
            // Loader 隐藏时停画，悬停看时钟不白烧 CPU
            running: lyricsRoot.visible
            repeat: true
            onTriggered: {
                const r = Cava.values
                if (!r || r.length < 30)
                    return

                function regionMax(start, end) {
                    let m = 0
                    for (let i = start; i <= end; i++) {
                        if ((r[i] || 0) > m)
                            m = r[i]
                    }
                    return m
                }

                const targets = [0, 0, 0, 0, 0, 0]
                targets[0] = Math.min(1, regionMax(16, 22) * 1.5)
                targets[5] = Math.min(1, regionMax(23, 29) * 1.5)
                targets[1] = Math.min(1, regionMax(6, 10) * 1.2)
                targets[4] = Math.min(1, regionMax(11, 15) * 1.2)
                targets[2] = regionMax(0, 2)
                targets[3] = regionMax(3, 5)
                const beat = Math.max(targets[2], targets[3])

                const s = lyricsRoot.smoothValues.slice()
                for (let i = 0; i < 6; i++) {
                    const finalTarget = Math.min(1, targets[i] * 0.8 + beat * 0.2)
                    const diff = finalTarget - s[i]
                    s[i] += (diff > 0 ? 0.85 : 0.08) * diff
                }
                lyricsRoot.smoothValues = s
                spectrumCanvas.requestPaint()
            }
        }

        Canvas {
            id: spectrumCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const s = lyricsRoot.smoothValues
                ctx.beginPath()
                ctx.lineCap = "round"
                ctx.lineWidth = 2.5
                ctx.strokeStyle = String(Color.primary)
                for (let i = 0; i < 6; i++) {
                    const val = Math.min(1, s[i] || 0)
                    const h = Math.max(3, val * height)
                    const x = 1.25 + i * 3.7
                    ctx.moveTo(x, height / 2 - h / 2)
                    ctx.lineTo(x, height / 2 + h / 2)
                }
                ctx.stroke()
            }
        }
    }

    // ---- 歌词（单行 + 过长跑马灯）----
    Item {
        id: lyricsSection
        anchors.left: coverBox.right
        anchors.leftMargin: lyricsRoot.gap
        anchors.right: spectrumBox.left
        anchors.rightMargin: lyricsRoot.gap
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        ListView {
            id: lyricsView
            anchors.fill: parent
            interactive: false
            model: Lyrics.lines
            currentIndex: Lyrics.currentIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0
            highlightMoveDuration: 360

            Connections {
                target: Lyrics
                function onCurrentIndexChanged() {
                    if (Lyrics.currentIndex >= 0)
                        lyricsView.positionViewAtIndex(Lyrics.currentIndex, ListView.Beginning)
                }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: ListView.view.width
                height: lyricsRoot.rowH
                clip: true

                readonly property bool isCurrent: index === Lyrics.currentIndex
                readonly property real scrollDistance: Math.max(0, lyricText.implicitWidth - width)

                // 用 Timer 代替 callLater，避免销毁后回调打到空对象
                Timer {
                    id: marqueeKick
                    interval: 1
                    repeat: false
                    onTriggered: {
                        if (!row.isCurrent)
                            return
                        lyricsRoot.updateTextWidth(lyricText.implicitWidth)
                        if (row.scrollDistance > 0) {
                            lyricText.x = 0
                            marqueeDelay.restart()
                        } else {
                            lyricText.x = Math.max(0, (row.width - lyricText.implicitWidth) / 2)
                        }
                    }
                }

                onIsCurrentChanged: {
                    scrollAnim.stop()
                    marqueeDelay.stop()
                    if (isCurrent)
                        marqueeKick.restart()
                }

                Connections {
                    target: lyricsRoot
                    enabled: row.isCurrent
                    function onMarqueeEpochChanged() {
                        scrollAnim.stop()
                        marqueeDelay.stop()
                        marqueeKick.restart()
                    }
                    function onVisibleChanged() {
                        if (!lyricsRoot.visible) {
                            scrollAnim.stop()
                            marqueeDelay.stop()
                            marqueeKick.stop()
                        }
                    }
                }

                // 文本异步排版后补测一次
                Connections {
                    target: lyricText
                    enabled: row.isCurrent
                    function onImplicitWidthChanged() {
                        lyricsRoot.updateTextWidth(lyricText.implicitWidth)
                        if (row.isCurrent && row.scrollDistance <= 0)
                            lyricText.x = Math.max(0, (row.width - lyricText.implicitWidth) / 2)
                    }
                }
                Timer {
                    id: marqueeDelay
                    interval: 800
                    repeat: false
                    onTriggered: {
                        if (row.isCurrent && row.scrollDistance > 0)
                            scrollAnim.restart()
                    }
                }

                SequentialAnimation {
                    id: scrollAnim
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: lyricText
                        property: "x"
                        to: -row.scrollDistance
                        duration: Math.max(800, row.scrollDistance * 22)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 800 }
                    NumberAnimation {
                        target: lyricText
                        property: "x"
                        to: 0
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                    PauseAnimation { duration: 600 }
                    ScriptAction {
                        script: {
                            if (row.scrollDistance <= 0)
                                lyricText.x = Math.max(0, (row.width - lyricText.implicitWidth) / 2)
                        }
                    }
                }

                Text {
                    id: lyricText
                    anchors.verticalCenter: parent.verticalCenter
                    // 短句居中；过长时从左侧起跑马灯
                    x: row.scrollDistance > 0 ? 0 : Math.max(0, (row.width - implicitWidth) / 2)
                    text: modelData.text || ""
                    textFormat: Text.PlainText
                    color: row.isCurrent ? Color.primary : Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    font.weight: Font.Bold
                }
            }
        }
    }
}
