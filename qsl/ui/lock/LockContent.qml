// LockContent — 锁屏（媒体优先）
//
// 有媒体：歌词浮在左，cava 沉在下半屏当背景，控件在左下
// （随机 / 上一 / 播放 / 下一 / 循环 + 音量）。时钟收到顶上，
// 待办跟时钟走（一行下一件；点开大钟才列出）。
// 通知是右上 toast；密码独占右下。没媒体时大钟回到左边。
// 天气不要了。不铺实色卡。
//
// 性能：Cava 只在有媒体时 acquire；歌词随 surface 生命周期；
// 通知 hydrate 一次，不设 uiActive；封面 sourceSize 小；无 FastBlur

import QtQuick
import qs.data.state
import qs.data.service

Item {
    id: root

    property bool unlocking: false
    property bool failed: false
    property bool dismissing: false
    property bool clockPeek: false

    signal submit()

    readonly property color ink: Qt.rgba(1, 1, 1, 0.96)
    readonly property color inkDim: Qt.rgba(1, 1, 1, 0.62)
    readonly property color inkFaint: Qt.rgba(1, 1, 1, 0.38)

    // 取值全部走 Media 的公开面。这里只留「没播放器时显示什么」——那是呈现决定，
    // 媒体页同一份数据显示的是「未知曲目」
    readonly property bool hasMedia: Media.hasActive
    readonly property bool showMedia: root.hasMedia && !root.clockPeek
    readonly property bool showHero: !root.hasMedia || root.clockPeek
    readonly property string trackTitle: Media.hasActive
        ? (Media.trackTitle || "未知曲目")
        : ""
    readonly property string trackArtist: Media.trackArtist
    readonly property string artUrl: Media.trackArtUrl
    readonly property real trackLength: Media.trackLength

    property real seekPos: 0
    property bool seeking: false
    property int expandedNotif: -1
    property bool _cavaHeld: false

    readonly property string timeStr: Qt.formatDateTime(Time.rawDate, "HH:mm")
    readonly property string dateStr: {
        void Time.rawDate
        const d = Time.rawDate
        return Qt.formatDateTime(d, "dddd") + " · "
            + (d.getMonth() + 1) + "月" + d.getDate() + "日"
    }
    readonly property string holidayLine: {
        const lunar = Calendar.todayLunar || ""
        const h = Calendar.nextHoliday
        let extra = ""
        if (h && h.name) {
            extra = h.daysAway <= 0
                ? (h.name + "中")
                : (h.name + "还有 " + h.daysAway + " 天")
        }
        if (lunar.length && extra.length)
            return "农历" + lunar + " · " + extra
        if (lunar.length)
            return "农历" + lunar
        return extra
    }

    readonly property var notifRows: {
        const list = Notification.entries || []
        const out = []
        const n = Math.min(list.length, 3)
        for (let i = 0; i < n; i++) {
            const e = list[i]
            if (!e)
                continue
            out.push({
                notifId: e.notifId,
                appName: e.appName || "",
                summary: e.summary || "",
                body: e.body || ""
            })
        }
        return out
    }

    readonly property var openTodos: {
        void Todo.revision
        const src = Todo.items || []
        const starred = []
        const rest = []
        for (let i = 0; i < src.length; i++) {
            const it = src[i]
            if (!it || it.done)
                continue
            if (it.starred)
                starred.push(it)
            else
                rest.push(it)
        }
        return starred.concat(rest)
    }
    readonly property var todoRows: {
        const t = root.openTodos
        return t.length > 4 ? t.slice(0, 4) : t
    }

    readonly property var lyricWindow: {
        const lines = Lyrics.lines || []
        const cur = Lyrics.currentIndex
        const out = []
        for (let i = cur - 2; i <= cur + 2; i++) {
            out.push({
                text: (i >= 0 && i < lines.length) ? String(lines[i].text || "") : " ",
                current: i === cur && i >= 0 && i < lines.length
            })
        }
        return out
    }

    readonly property string volIcon: {
        if (!Volume.hasSink || Volume.sinkMuted)
            return "volume_off"
        const v = Volume.sinkVolume || 0
        if (v >= 0.66)
            return "volume_up"
        if (v >= 0.33)
            return "volume_down"
        return "volume_mute"
    }

    function focusInput() {
        if (!dismissing)
            pwdInput.forceActiveFocus()
    }

    function clearInput() {
        pwdInput.text = ""
    }

    function passwordText() {
        return pwdInput.text
    }

    function shakePassword() {
        shakeAnim.restart()
    }

    function _holdCava(want) {
        if (want === root._cavaHeld)
            return
        root._cavaHeld = want
        if (want)
            Cava.acquire()
        else
            Cava.release()
    }

    onHasMediaChanged: {
        if (!hasMedia)
            clockPeek = false
        root._holdCava(hasMedia && !dismissing)
        Media.syncLyrics()
    }

    onDismissingChanged: root._holdCava(hasMedia && !dismissing)

    // 换播放器或换曲目都由 Media.trackChanged 一个信号覆盖
    Connections {
        target: Media
        function onTrackChanged() { Media.syncLyrics() }
    }
    Connections {
        target: Cava
        enabled: root._cavaHeld
        function onValuesChanged() { cavaCanvas.requestPaint() }
    }

    // ---- cava：下半屏背景，不是控件 ----
    Canvas {
        id: cavaCanvas
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.46
        opacity: root.hasMedia ? 0.5 : 0.16
        z: 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            ctx.reset()
            const vals = Cava.values || []
            const n = 30
            const gap = 3
            const barW = Math.max(2, (w - gap * (n - 1)) / n)
            const c0 = String(Color.primary)
            const c1 = String(Color.inversePrimary)
            for (let i = 0; i < n; i++) {
                const v = Math.max(0, Math.min(1, Number(vals[i]) || 0))
                const bh = Math.max(4, v * h)
                const x = i * (barW + gap)
                ctx.globalAlpha = 0.2 + 0.8 * v
                const g = ctx.createLinearGradient(0, h, 0, h - bh)
                g.addColorStop(0, c0)
                g.addColorStop(1, c1)
                ctx.fillStyle = g
                ctx.fillRect(x, h - bh, barW, bh)
            }
        }
        Behavior on opacity { Anim { type: Anim.Effects } }
    }

    // ---- 顶：有媒体时的小钟 + 下一件待办 ----
    // MouseArea 不能当 Column 的子项再 anchors.fill：会把后面的行顶到 y=0
    Item {
        id: clockMini
        visible: root.showMedia
        opacity: visible ? 1 : 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 26
        width: miniCol.implicitWidth
        height: miniCol.implicitHeight
        z: 2
        Behavior on opacity { Anim { type: Anim.Effects } }

        Column {
            id: miniCol
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeStr
                color: root.ink
                font.family: Size.fontMono
                font.pixelSize: 56
                font.weight: Font.ExtraLight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateStr
                color: root.inkDim
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.lg
            }
            Text {
                visible: root.openTodos.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: 480
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: {
                    const t = root.openTodos[0]
                    if (!t)
                        return ""
                    const head = (t.starred ? "★ " : "") + (t.text || "")
                    return root.openTodos.length > 1
                        ? (head + "  ·  还有 " + (root.openTodos.length - 1) + " 件")
                        : head
                }
                color: root.inkDim
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.lg
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clockPeek = true
        }
    }

    // ---- 大钟（没媒体，或点小钟 peek）+ 待办列表 ----
    Column {
        id: clockHero
        visible: root.showHero
        opacity: visible ? 1 : 0
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Math.round(parent.width * 0.07)
        width: Math.min(560, parent.width * 0.5)
        spacing: 10
        z: 2
        Behavior on opacity { Anim { type: Anim.Effects } }

        Text {
            text: root.timeStr
            color: root.ink
            font.family: Size.fontMono
            font.pixelSize: 136
            font.weight: Font.ExtraLight

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.hasMedia)
                        root.clockPeek = false
                    else
                        root.focusInput()
                }
            }
        }
        Text {
            text: root.dateStr
            color: root.inkDim
            font.family: Size.fontSans
            font.pixelSize: 22

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.hasMedia)
                        root.clockPeek = false
                    else
                        root.focusInput()
                }
            }
        }
        Text {
            visible: root.holidayLine.length > 0
            text: root.holidayLine
            color: root.inkFaint
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.md

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.hasMedia)
                        root.clockPeek = false
                    else
                        root.focusInput()
                }
            }
        }

        Column {
            visible: root.openTodos.length > 0
            width: parent.width
            topPadding: 18
            spacing: 6

            Repeater {
                model: root.todoRows
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
                            border.color: root.inkFaint
                        }

                        Column {
                            id: todoCol
                            width: parent.width - 28
                            spacing: 3
                            Text {
                                width: parent.width
                                text: modelData.text || ""
                                color: root.ink
                                font.family: Size.fontSans
                                font.pixelSize: 20
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: (modelData.tag || "").length > 0 || modelData.starred
                                text: (modelData.starred ? "★ 重要  " : "") + (modelData.tag || "")
                                color: modelData.starred ? Color.inversePrimary : root.inkFaint
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.sm
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.id)
                                Todo.toggle(modelData.id)
                            root.focusInput()
                        }
                    }
                }
            }
        }
    }

    // ---- 左：歌词 ----
    Column {
        visible: root.showMedia
        opacity: visible ? 1 : 0
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 56
        anchors.verticalCenterOffset: -20
        width: Math.min(520, parent.width * 0.46)
        spacing: 10
        z: 1
        Behavior on opacity { Anim { type: Anim.Effects } }

        Repeater {
            model: root.lyricWindow
            delegate: Text {
                required property var modelData
                width: parent.width
                text: modelData.text
                color: modelData.current ? root.ink : root.inkFaint
                font.family: Size.fontSans
                font.pixelSize: modelData.current ? 32 : 16
                font.weight: modelData.current ? Font.DemiBold : Font.Normal
                wrapMode: Text.WordWrap
                Behavior on font.pixelSize { Anim { type: Anim.Effects } }
                Behavior on color { CAnim {} }
            }
        }
    }

    // ---- 左下：媒体控件 ----
    Column {
        visible: root.showMedia
        opacity: visible ? 1 : 0
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56
        anchors.bottomMargin: 36
        width: Math.min(560, parent.width * 0.5)
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
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 112
                    sourceSize.height: 112
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.artUrl.length === 0
                    text: "album"
                    color: root.ink
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
                    text: root.trackTitle
                    color: root.ink
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.lg
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.trackArtist.length
                        ? root.trackArtist
                        : (Media.activeIdentity || "")
                    color: root.inkDim
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
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
                        const len = root.trackLength
                        if (len <= 0)
                            return 0
                        return parent.width * Math.max(0, Math.min(1, root.seekPos / len))
                    }
                    radius: parent.radius
                    color: root.ink
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                enabled: Media.canSeek && root.trackLength > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: root.seeking = true
                onReleased: (mouse) => {
                    if (root.trackLength > 0) {
                        Media.seekFraction(mouse.x / width)
                        root.seekPos = Media.position()
                    }
                    root.seeking = false
                    root.focusInput()
                }
                onPositionChanged: (mouse) => {
                    if (!pressed || root.trackLength <= 0)
                        return
                    root.seekPos = Math.max(0, Math.min(1, mouse.x / width)) * root.trackLength
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
                    root.focusInput()
                }
            }
            LockIconBtn {
                glyph: "skip_previous"
                onTriggered: {
                    Media.previousTrack()
                    root.focusInput()
                }
            }
            LockIconBtn {
                glyph: Media.playing ? "pause" : "play_arrow"
                primary: true
                onTriggered: {
                    Media.playPause()
                    root.focusInput()
                }
            }
            LockIconBtn {
                glyph: "skip_next"
                onTriggered: {
                    Media.nextTrack()
                    root.focusInput()
                }
            }
            LockIconBtn {
                glyph: Media.loopOne ? "repeat_one" : "repeat"
                active: Media.loopOn
                enabled: Media.loopOk
                onTriggered: {
                    Media.cycleLoop()
                    root.focusInput()
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
                    text: root.volIcon
                    color: Volume.sinkMuted ? Color.error : root.inkDim
                    font.family: Size.fontIcon
                    font.pixelSize: 20
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: Volume.hasSink
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            Volume.toggleSinkMute()
                            root.focusInput()
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
                            color: root.ink
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
                        onReleased: root.focusInput()
                    }
                }
            }
        }
    }

    // ---- 右上：通知 toast ----
    Column {
        visible: root.notifRows.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 28
        anchors.rightMargin: 36
        width: 300
        spacing: 8
        z: 3

        Repeater {
            model: root.notifRows
            delegate: Rectangle {
                id: toastCard
                required property var modelData
                readonly property bool open: root.expandedNotif === modelData.notifId
                width: 300
                height: toastCol.implicitHeight + 20
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    id: toastCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 3

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 20
                            text: modelData.appName || "应用"
                            color: Color.inversePrimary
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.xsm
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "close"
                            color: root.inkFaint
                            font.family: Size.fontIcon
                            font.pixelSize: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Notification.dismiss(modelData.notifId)
                                    root.focusInput()
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        text: modelData.summary || ""
                        color: root.ink
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.sm
                        font.weight: Font.Medium
                        elide: toastCard.open ? Text.ElideNone : Text.ElideRight
                        wrapMode: toastCard.open ? Text.Wrap : Text.NoWrap
                        maximumLineCount: toastCard.open ? 4 : 1
                    }
                    Text {
                        width: parent.width
                        visible: toastCard.open
                            && (modelData.body || "").length > 0
                            && modelData.body !== modelData.summary
                        text: modelData.body || ""
                        color: root.inkDim
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.expandedNotif = open ? -1 : modelData.notifId
                        root.focusInput()
                    }
                }
            }
        }

        Text {
            visible: root.notifRows.length > 0
            anchors.right: parent.right
            text: "全部清除"
            color: root.inkFaint
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.sm
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Notification.dismissAll()
                    root.focusInput()
                }
            }
        }
    }

    // ---- 右下：密码 ----
    Item {
        id: pwdWrap
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 36
        anchors.bottomMargin: 36
        width: 300
        height: 54
        z: 3
        transform: Translate { id: pwdShake; x: 0 }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1.5
            border.color: root.failed
                ? Color.error
                : (pwdInput.activeFocus
                    ? Qt.rgba(1, 1, 1, 0.7)
                    : Qt.rgba(1, 1, 1, 0.22))
            Behavior on border.color { CAnim {} }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 18
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    font.family: Size.fontIcon
                    font.pixelSize: 20
                    color: root.failed ? Color.error : root.inkFaint
                }

                TextInput {
                    id: pwdInput
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.ink
                    font.pixelSize: 15
                    font.family: Size.fontSans
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    clip: true
                    focus: true
                    selectByMouse: true
                    enabled: !root.unlocking && !root.dismissing
                    horizontalAlignment: Text.AlignHCenter

                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: {
                        if (root.clockPeek)
                            root.clockPeek = false
                    }

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        visible: !pwdInput.text
                        text: root.unlocking ? "验证中…" : (root.failed ? "密码错误" : "输入密码")
                        color: root.failed ? Color.error : root.inkFaint
                        font: pwdInput.font
                    }
                }
            }
        }
    }

    // 装饰性/刷新动画，不走令牌（plan.md 白名单）：密码错误抖动
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: pwdShake; property: "x"; to: 14; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -12; duration: 50 }
        NumberAnimation { target: pwdShake; property: "x"; to: 8; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -6; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: 0; duration: 40 }
    }

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
            color: btn.active ? Color.inversePrimary : root.ink
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

    Timer {
        interval: 500
        running: root.hasMedia && !root.dismissing
        repeat: true
        onTriggered: {
            if (!root.seeking)
                root.seekPos = Media.position()
            if (Media.isMusic)
                Lyrics.syncPosition(root.seekPos)
        }
    }

    Component.onCompleted: {
        Notification.hydrate()
        Qt.callLater(() => Notification.refresh())
        Lyrics.acquire()
        root._holdCava(root.hasMedia && !root.dismissing)
        Media.syncLyrics()
        pwdInput.forceActiveFocus()
    }

    Component.onDestruction: {
        Lyrics.release()
        root._holdCava(false)
        if (!Notification.uiActive)
            Notification.release()
    }
}
