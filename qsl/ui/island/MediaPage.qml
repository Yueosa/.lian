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
//
// 第 10 轮拆分（原 785 行）：
//   MediaWave          左栏那条波形进度条（原「频谱驱动」一段，200 行）
//   MediaLyrics        右栏：歌词通高 + 底下一条 cava
//   MediaPlayerPicker  右上角的播放器选择器
//   MediaCtrlBtn       原来的内联 component
//
// 留在本文件的是编排，外加**跨区共用**的那几样：seekPos / seeking 被波形条、
// 时间标签和 200ms 的轮询 Timer 同时用，Cava/Lyrics 的 acquire/release 是整页
// 的生命周期。左栏没有再往外摘——把波形条拿走之后，它剩下的正好就是这几份
// 状态的呈现面，再拆一层只会让 seek 的信号多转一道手。

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

            // 拖动不在波形条里落地：seekPos 还有时间标签和轮询 Timer 在读，
            // 只能有一个人写
            MediaWave {
                page: root
                onSeekBegan: root.seeking = true
                onSeekDragged: (pos) => root.seekPos = pos
                onSeekCommitted: (frac) => {
                    if (root.trackLength > 0) {
                        Media.seekFraction(frac)
                        root.seekPos = Media.position()
                    }
                    root.seeking = false
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
        MediaLyrics {
            shown: stagger.shown(1)
        }
    }

    // ---- 播放器选择器：整页右上角，浮在歌词上面 ----
    // 换播放器是低频操作，不该在左栏正文里占一条位置；收起时只是一颗药丸，
    // 展开才往下掉一列
    MediaPlayerPicker {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        hasPlayer: root.hasPlayer
        shown: stagger.shown(2)
    }
}
