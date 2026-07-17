// MediaPage — Hub 瘦身媒体页
// 左：封面 / 频谱 / 展开式播放器；右：歌名 → 歌词（无容器、高亮居中）→ 底操控
// 性能：随 Loader 销毁；Cava.acquire/release；无 FastBlur / 无圆形频谱

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.data.state
import qs.data.service

Item {
    id: root

    readonly property var player: Media.active
    readonly property bool hasPlayer: !!player
    readonly property bool isMusic: Media.isMusicPlayer(player)

    readonly property string trackTitle: player ? (player.trackTitle || "未知曲目") : "未知曲目"
    readonly property string trackArtist: player ? (player.trackArtist || "未知艺人") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real trackLength: player ? (Number(player.length) || 0) : 0
    readonly property bool isPlaying: !!(player && player.isPlaying)
    readonly property bool shuffleOn: !!(player && player.shuffle)
    readonly property bool shuffleOk: !!(player && player.shuffleSupported)
    readonly property bool loopOk: !!(player && player.loopSupported)
    readonly property bool canSeek: !!(player && player.canSeek)
    readonly property var loopState: player ? player.loopState : MprisLoopState.None

    property real seekPos: 0
    property bool seeking: false
    property bool playerExpanded: false

    function formatTime(sec) {
        let s = Number(sec) || 0
        if (s > 100000)
            s = s / 1000000
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + String(r).padStart(2, "0")
    }

    function refreshLyrics() {
        if (!player) {
            Lyrics.setPlaceholder("")
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

    function cycleLoop() {
        if (!player || !player.loopSupported)
            return
        if (player.loopState === MprisLoopState.None)
            player.loopState = MprisLoopState.Playlist
        else if (player.loopState === MprisLoopState.Playlist)
            player.loopState = MprisLoopState.Track
        else
            player.loopState = MprisLoopState.None
    }

    function centerLyric() {
        if (Lyrics.currentIndex >= 0)
            lyricsList.positionViewAtIndex(Lyrics.currentIndex, ListView.Center)
    }

    Component.onCompleted: {
        Cava.acquire()
        Lyrics.acquire()
        refreshLyrics()
    }
    Component.onDestruction: {
        Cava.release()
        Lyrics.release()
    }

    Connections {
        target: Media
        function onActiveChanged() {
            root.refreshLyrics()
            root.playerExpanded = false
        }
    }
    Connections {
        target: root.player
        enabled: root.hasPlayer
        function onTrackTitleChanged() { root.refreshLyrics() }
        function onTrackArtistChanged() { root.refreshLyrics() }
    }

    Timer {
        interval: 200
        running: root.hasPlayer
        repeat: true
        onTriggered: {
            if (!root.seeking && root.player)
                root.seekPos = Number(root.player.position) || 0
            if (root.isMusic)
                Lyrics.syncPosition(root.seekPos)
        }
    }

    // ---- 无播放器占位 ----
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
            font.pixelSize: Size.fontSize.lg
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 24
        visible: root.hasPlayer

        // ---- 左：封面 + 频谱 + 展开播放器 ----
        ColumnLayout {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            spacing: Size.spacing.md

            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200
                Layout.alignment: Qt.AlignHCenter
                radius: Size.rounding.lg
                color: Color.surfaceHighest
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(400, 400)
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.artUrl.length
                    text: Media.activeIdentityIcon
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: 56
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 48
                spacing: 3
                Repeater {
                    model: 12
                    Rectangle {
                        required property int index
                        width: 10
                        height: {
                            const vals = Cava.values
                            if (!vals || vals.length < 30)
                                return 4
                            const a = index * 2
                            const b = a + 1
                            const c = Math.min(29, a + 2)
                            const v = ((vals[a] || 0) + (vals[b] || 0) + (vals[c] || 0)) / 3
                            return 4 + v * 44
                        }
                        anchors.bottom: parent.bottom
                        radius: 2
                        color: Color.primary
                        Behavior on height {
                            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }

            // 播放器：点开在下方展开，不浮层
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Size.rounding.md
                    color: playerChipMa.containsMouse || root.playerExpanded
                        ? Color.surfaceHighest
                        : Color.surfaceHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8
                        Text {
                            text: Media.activeIdentityIcon
                            color: Color.primary
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.md
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Media.activeIdentity
                            color: Color.textOnBackground
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.sm
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.playerExpanded ? "\uf077" : "\uf078"
                            color: Color.textMuted
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.xsm
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
                    Layout.fillWidth: true
                    visible: root.playerExpanded
                    spacing: 2

                    Repeater {
                        model: Media.list
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 30
                            radius: Size.rounding.sm
                            color: {
                                if (modelData === Media.active)
                                    return Color.withAlpha(Color.primary, 0.22)
                                return itemMa.containsMouse ? Color.surfaceHighest : "transparent"
                            }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                text: Media.getIdentityIcon(modelData) + "  " + Media.getIdentity(modelData)
                                color: modelData === Media.active ? Color.primary : Color.textOnBackground
                                font.pixelSize: Size.fontSize.sm
                                font.bold: modelData === Media.active
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            MouseArea {
                                id: itemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Media.selectPlayer(modelData)
                                    root.playerExpanded = false
                                    root.refreshLyrics()
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ---- 右：歌名 → 歌词 → 底操控 ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Size.spacing.sm

            // 顶：歌名 / 艺人
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: Color.textOnBackground
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.title
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    elide: Text.ElideRight
                }
            }

            // 中：歌词直接铺在背景上，当前行垂直居中 + 放大高亮
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8
                clip: true

                ListView {
                    id: lyricsList
                    anchors.fill: parent
                    clip: true
                    reuseItems: true
                    spacing: 14
                    model: Lyrics.lines
                    currentIndex: Lyrics.currentIndex
                    // 当前行钉在垂直中线
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: height / 2 - 28
                    preferredHighlightEnd: height / 2 + 28
                    highlightMoveDuration: 220
                    highlightMoveVelocity: -1

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
                            font.pixelSize: parent.isCurrent ? 28 : Size.fontSize.md
                            font.bold: parent.isCurrent
                            font.weight: parent.isCurrent ? Font.DemiBold : Font.Normal
                            opacity: parent.isCurrent ? 1.0 : 0.45
                            Behavior on font.pixelSize {
                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 160 }
                            }
                        }
                    }
                }

                // 上下淡出，强化「中间是焦点」
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36
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
                    font.pixelSize: Size.fontSize.md
                }
            }

            // 底：进度 + 传输键
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        radius: 3
                        color: Color.surfaceHighest

                        Rectangle {
                            width: {
                                if (root.trackLength <= 0)
                                    return 0
                                return parent.width * Math.max(0, Math.min(1, root.seekPos / root.trackLength))
                            }
                            height: parent.height
                            radius: 3
                            color: Color.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.seeking = true
                        onReleased: (mouse) => {
                            if (root.player && root.trackLength > 0 && root.canSeek) {
                                const ratio = Math.max(0, Math.min(1, mouse.x / width))
                                root.player.position = ratio * root.trackLength
                                root.seekPos = Number(root.player.position) || 0
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

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: root.formatTime(root.seekPos)
                        color: Color.textMuted
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.xsm
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.formatTime(root.trackLength)
                        color: Color.textMuted
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.xsm
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    MediaCtrlBtn {
                        glyph: "\uf074"
                        active: root.shuffleOn
                        enabled: root.shuffleOk
                        onTriggered: {
                            if (root.player)
                                root.player.shuffle = !root.player.shuffle
                        }
                    }
                    MediaCtrlBtn {
                        glyph: "\uf048"
                        onTriggered: {
                            if (root.player)
                                root.player.previous()
                        }
                    }
                    MediaCtrlBtn {
                        glyph: root.isPlaying ? "\uf04c" : "\uf04b"
                        primary: true
                        onTriggered: {
                            if (root.player)
                                root.player.togglePlaying()
                        }
                    }
                    MediaCtrlBtn {
                        glyph: "\uf051"
                        onTriggered: {
                            if (root.player)
                                root.player.next()
                        }
                    }
                    MediaCtrlBtn {
                        glyph: root.loopState === MprisLoopState.Track ? "\uf021" : "\uf079"
                        active: root.loopState !== MprisLoopState.None
                        enabled: root.loopOk
                        onTriggered: root.cycleLoop()
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

        width: primary ? 52 : 40
        height: primary ? 52 : 40
        radius: width / 2
        color: {
            if (primary)
                return Color.primary
            if (active)
                return Color.withAlpha(Color.primary, 0.25)
            return ma.containsMouse ? Color.surfaceHighest : Color.surfaceHigh
        }
        opacity: enabled ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: primary ? Color.textOnPrimary : (active ? Color.primary : Color.textOnBackground)
            font.family: Size.fontMono
            font.pixelSize: primary ? Size.fontSize.xl : Size.fontSize.lg
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
