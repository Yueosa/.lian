// MediaPlayerPicker — 媒体页右上角那颗播放器药丸，展开是一列可选播放器
//
// 第 10 轮从 MediaPage 摘出来。展开状态（原来的 root.playerExpanded）没人跨区读，
// 跟着一起搬进来了；连带那句"换了播放器就收起来"的 Connections——它原先跟
// syncLyrics 挤在页根同一个 Connections 里，其实说的是本件的事。
//
// 位置由页面给（anchors），本件只管自己多大、开着还是收着。
//
// 跟页面的接口：
//   hasPlayer —— 没播放器时整个藏掉
//   shown     —— 错峰入场，由页面的 QslStagger 给

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: playerPicker

    property bool hasPlayer: false
    property bool shown: false
    property bool expanded: false

    width: 184
    height: 28
    z: 50
    visible: hasPlayer
    opacity: shown ? 1 : 0
    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

    Connections {
        target: Media
        function onActiveChanged() { playerPicker.expanded = false }
    }

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
            selected: playerPicker.expanded
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
                text: playerPicker.expanded ? "\uf077" : "\uf078"
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
            onClicked: playerPicker.expanded = !playerPicker.expanded
        }
    }

    Column {
        anchors.top: pickerChip.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2
        visible: playerPicker.expanded

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
                        playerPicker.expanded = false
                    }
                }
            }
        }
    }
}
