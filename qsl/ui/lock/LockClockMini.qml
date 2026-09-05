// LockClockMini — 有媒体时收到屏顶的小钟：时间 + 日期 + 下一件待办一行
//
// 点它 = 展开大钟（peek）。第 10 轮从 LockContent 摘出来。
//
// 属性都由页根显式传进来，不回引页根：ink 那三档在锁屏里被引用二十几次，
// 走回引的话每个绑定在 page 赋值之前都要报一次 null，日志就没法看了。

import QtQuick
import qs.data.state

Item {
    id: clockMini

    property color ink: "white"
    property color inkDim: "white"
    property string timeStr: ""
    property string dateStr: ""
    property var openTodos: []

    signal peekRequested()

    opacity: visible ? 1 : 0
    width: miniCol.implicitWidth
    height: miniCol.implicitHeight
    z: 2
    Behavior on opacity { Anim { type: Anim.Effects } }

    Column {
        id: miniCol
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clockMini.timeStr
            color: clockMini.ink
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.displayLarge
            font.weight: Font.ExtraLight
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: clockMini.dateStr
            color: clockMini.inkDim
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.bodyLarge
        }
        Text {
            visible: clockMini.openTodos.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: 480
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: {
                const t = clockMini.openTodos[0]
                if (!t)
                    return ""
                const head = (t.starred ? "★ " : "") + (t.text || "")
                return clockMini.openTodos.length > 1
                    ? (head + "  ·  还有 " + (clockMini.openTodos.length - 1) + " 件")
                    : head
            }
            color: clockMini.inkDim
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.bodyLarge
        }
    }

    // MouseArea 不能当 Column 的子项再 anchors.fill：会把后面的行顶到 y=0
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clockMini.peekRequested()
    }
}
