// LockLyrics — 锁屏左侧歌词：当前行前后各两句，共五行
//
// 焦点行靠字号 + 字重 + 颜色三样一起变。这里跟岛内歌词不同：岛内为了不闪
// 换行把字号钉死了只动 scale，锁屏这五行是定宽不折行的，改字号不会重排。
// 第 10 轮从 LockContent 摘出来。

import QtQuick
import qs.data.state

Column {
    id: lyrics

    property color ink: "white"
    property color inkFaint: "white"
    property var lyricWindow: []

    opacity: visible ? 1 : 0
    spacing: 10
    z: 1
    Behavior on opacity { Anim { type: Anim.Effects } }

    Repeater {
        model: lyrics.lyricWindow
        delegate: Text {
            required property var modelData
            width: parent.width
            text: modelData.text
            color: modelData.current ? lyrics.ink : lyrics.inkFaint
            font.family: Size.fontSans
            font.pixelSize: modelData.current ? 32 : 16
            font.weight: modelData.current ? Font.DemiBold : Font.Normal
            wrapMode: Text.WordWrap
            Behavior on font.pixelSize { Anim { type: Anim.Effects } }
            Behavior on color { CAnim {} }
        }
    }
}
