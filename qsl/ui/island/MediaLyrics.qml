// MediaLyrics — 媒体页右栏：歌词通高 + 底下通宽一条 cava
//
// 第 10 轮从 MediaPage 摘出来。centerLyric() 原先长在页头、要滚的 ListView 长在
// 四百行开外，现在"谁把当前句拉回中间"和"拉的是哪个表"在同一个文件里；页根也不
// 再挂一个只有这一区用得上的函数。
//
// 跟页面的接口只有一个 shown（错峰入场，由页面的 QslStagger 给）。歌词跟着
// Lyrics 服务走，cava 跟着 Cava 走，都不经页根中转。

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

ColumnLayout {
    id: lyricsCol

    property bool shown: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 8
    opacity: shown ? 1 : 0
    transform: Translate {
        y: lyricsCol.shown ? 0 : 12
        Behavior on y { Anim { type: Anim.Enter } }
    }
    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

    function centerLyric() {
        if (Lyrics.currentIndex >= 0)
            lyricsList.positionViewAtIndex(Lyrics.currentIndex, ListView.Center)
    }

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
                    lyricsCol.centerLyric()
                }
                function onLinesChanged() {
                    Qt.callLater(lyricsCol.centerLyric)
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
