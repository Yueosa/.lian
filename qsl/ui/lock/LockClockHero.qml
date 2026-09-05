// LockClockHero — 大钟 + 待办列表。没媒体时它就是主角；有媒体时点小钟才 peek 出来
//
// 三行文字（时间/日期/节气节日）各自带一个 MouseArea，行为一致：有媒体就收回
// peek，没媒体就把焦点还给密码框。第 10 轮从 LockContent 摘出来时保持原样——
// 三块热区分开是有意的，合成一整块会连待办列表的点击一起吃掉。

import QtQuick
import qs.data.state
import qs.data.service

Column {
    id: clockHero

    property color ink: "white"
    property color inkDim: "white"
    property color inkFaint: "white"
    property string timeStr: ""
    property string dateStr: ""
    property string holidayLine: ""
    property var openTodos: []
    property var todoRows: []
    // 有媒体 → 点一下收回 peek；没媒体 → 点一下把焦点还给密码框
    property bool hasMedia: false

    signal peekDismissed()
    signal focusWanted()

    opacity: visible ? 1 : 0
    spacing: 10
    z: 2
    Behavior on opacity { Anim { type: Anim.Effects } }

    function _tapped() {
        if (clockHero.hasMedia)
            clockHero.peekDismissed()
        else
            clockHero.focusWanted()
    }

    Text {
        text: clockHero.timeStr
        color: clockHero.ink
        font.family: Size.fontMono
        font.pixelSize: Size.fontSize.displayHero
        font.weight: Font.ExtraLight

        MouseArea {
            anchors.fill: parent
            onClicked: clockHero._tapped()
        }
    }
    Text {
        text: clockHero.dateStr
        color: clockHero.inkDim
        font.family: Size.fontSans
        font.pixelSize: 22

        MouseArea {
            anchors.fill: parent
            onClicked: clockHero._tapped()
        }
    }
    Text {
        visible: clockHero.holidayLine.length > 0
        text: clockHero.holidayLine
        color: clockHero.inkFaint
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.bodyMedium

        MouseArea {
            anchors.fill: parent
            onClicked: clockHero._tapped()
        }
    }

    Column {
        visible: clockHero.openTodos.length > 0
        width: parent.width
        topPadding: 18
        spacing: 6

        Repeater {
            model: clockHero.todoRows
            delegate: Item {
                required property var modelData
                width: clockHero.width
                height: todoCol.implicitHeight + 14

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 5
                        y: 4
                        color: "transparent"
                        border.width: 1.5
                        border.color: clockHero.inkFaint
                    }

                    Column {
                        id: todoCol
                        width: parent.width - 28
                        spacing: 3
                        Text {
                            width: parent.width
                            text: modelData.text || ""
                            color: clockHero.ink
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.titleLarge
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: (modelData.tag || "").length > 0 || modelData.starred
                            text: (modelData.starred ? "★ 重要  " : "") + (modelData.tag || "")
                            color: modelData.starred ? Color.inversePrimary : clockHero.inkFaint
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.bodySmall
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.id)
                            Todo.toggle(modelData.id)
                        clockHero.focusWanted()
                    }
                }
            }
        }
    }
}
