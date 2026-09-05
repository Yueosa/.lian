// MediaCtrlBtn — 媒体页那排圆钮：随机 / 上一首 / 播放暂停 / 下一首 / 循环
//
// 第 10 轮从 MediaPage 的内联 component 摘出来，类型名照旧。
// 禁用不用自己拦：Item 的 enabled 会连着子级一起关，MouseArea 跟着不收事件，
// 所以这里只管把 opacity 压到 0.35 表示"点不动"。
//
// 跟页面的接口：glyph / active / primary 三个属性 + triggered() 信号。

import QtQuick
import qs.Components
import qs.data.state

Rectangle {
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
            return Color.primaryContainer
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
        color: primary ? Color.primaryText : (active ? Color.primaryContainerText : Color.backgroundText)
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
