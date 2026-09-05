// LockMediaControls — 锁屏左下：封面 + 曲目 + 进度条 + 五个传输键 + 音量
//
// 第 10 轮从 LockContent 摘出来（原文件里这块 228 行，是最大的一区）。
//
// 每个操作做完都要把焦点还给密码框——锁屏上任何一次点击都会把焦点从密码框
// 抢走，不还回去用户就得再点一下密码框才能打字。所以这里每个 handler 末尾
// 都有一次 focusWanted()，别当成复制粘贴的冗余删掉。

import QtQuick
import qs.data.state
import qs.data.service

Column {
    id: controls

    property color ink: "white"
    property color inkDim: "white"
    property string artUrl: ""
    property string trackTitle: ""
    property string trackArtist: ""
    property real trackLength: 0
    property string volIcon: "volume_up"
    // 进度：拖动期间由本件写回页根，定时器就不再覆盖它
    property real seekPos: 0
    property bool seeking: false

    signal seekPosChangeRequested(real pos)
    signal seekingChangeRequested(bool active)
    signal focusWanted()

    opacity: visible ? 1 : 0
    spacing: 8
    z: 2
    Behavior on opacity { Anim { type: Anim.Effects } }

    Row {
        spacing: 14

        Rectangle {
            width: 56
            height: 56
            radius: 12
            color: Color.withAlpha(Color.primary, 0.45)
            clip: true

            Image {
                anchors.fill: parent
                source: controls.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 112
                sourceSize.height: 112
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: controls.artUrl.length === 0
                text: "album"
                color: controls.ink
                font.family: Size.fontIcon
                font.pixelSize: 26
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 400
            spacing: 3
            Text {
                width: parent.width
                text: controls.trackTitle
                color: controls.ink
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.titleMedium
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: controls.trackArtist.length
                    ? controls.trackArtist
                    : (Media.activeIdentity || "")
                color: controls.inkDim
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.bodySmall
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: parent.width
        height: 16

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.18)
            Rectangle {
                height: parent.height
                width: {
                    const len = controls.trackLength
                    if (len <= 0)
                        return 0
                    return parent.width * Math.max(0, Math.min(1, controls.seekPos / len))
                }
                radius: parent.radius
                color: controls.ink
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            enabled: Media.canSeek && controls.trackLength > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: controls.seekingChangeRequested(true)
            onReleased: (mouse) => {
                if (controls.trackLength > 0) {
                    Media.seekFraction(mouse.x / width)
                    controls.seekPosChangeRequested(Media.position())
                }
                controls.seekingChangeRequested(false)
                controls.focusWanted()
            }
            onPositionChanged: (mouse) => {
                if (!pressed || controls.trackLength <= 0)
                    return
                controls.seekPosChangeRequested(
                    Math.max(0, Math.min(1, mouse.x / width)) * controls.trackLength)
            }
        }
    }

    Row {
        width: parent.width
        spacing: 4

        LockIconBtn {
            glyph: "shuffle"
            active: Media.shuffleOn
            enabled: Media.shuffleOk
            onTriggered: {
                Media.toggleShuffle()
                controls.focusWanted()
            }
        }
        LockIconBtn {
            glyph: "skip_previous"
            onTriggered: {
                Media.previousTrack()
                controls.focusWanted()
            }
        }
        LockIconBtn {
            glyph: Media.playing ? "pause" : "play_arrow"
            primary: true
            onTriggered: {
                Media.playPause()
                controls.focusWanted()
            }
        }
        LockIconBtn {
            glyph: "skip_next"
            onTriggered: {
                Media.nextTrack()
                controls.focusWanted()
            }
        }
        LockIconBtn {
            glyph: Media.loopOne ? "repeat_one" : "repeat"
            active: Media.loopOn
            enabled: Media.loopOk
            onTriggered: {
                Media.cycleLoop()
                controls.focusWanted()
            }
        }

        Item { width: 12; height: 1 }

        Item {
            width: 132
            height: 36
            anchors.verticalCenter: parent.verticalCenter
            opacity: Volume.hasSink ? 1 : 0.4

            Text {
                id: volGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: controls.volIcon
                color: Volume.sinkMuted ? Color.error : controls.inkDim
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.xl
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: Volume.hasSink
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        Volume.toggleSinkMute()
                        controls.focusWanted()
                    }
                }
            }

            Item {
                anchors.left: volGlyph.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 16

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.18)
                    Rectangle {
                        height: parent.height
                        width: parent.width * (Volume.sinkMuted ? 0 : (Volume.sinkVolume || 0))
                        radius: parent.radius
                        color: controls.ink
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    enabled: Volume.hasSink
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    preventStealing: true
                    onPressed: (mouse) => {
                        Volume.setSinkVolume(Math.max(0, Math.min(1, mouse.x / width)))
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            Volume.setSinkVolume(Math.max(0, Math.min(1, mouse.x / width)))
                    }
                    onReleased: controls.focusWanted()
                }
            }
        }
    }

    // 只有这一区用，留成内联件：搬成独立文件反而要把 ink 再往下传一层
    component LockIconBtn: Item {
        id: btn
        property string glyph: ""
        property bool primary: false
        property bool active: false
        signal triggered()

        width: primary ? 44 : 36
        height: width

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: primary
                ? Qt.rgba(1, 1, 1, 0.16)
                : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
            opacity: btn.enabled ? 1 : 0.35
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.active ? Color.inversePrimary : controls.ink
            font.family: Size.fontIcon
            font.pixelSize: btn.primary ? 24 : 20
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
