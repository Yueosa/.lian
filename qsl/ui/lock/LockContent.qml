// LockContent — 锁屏构图（底栏方案 B）
// 左上天气 · 右上通知 · 中轴时钟+密码 · 底中单行媒体条（音量内嵌）
// 不做日历/Todo；无紧急解锁热区
// 性能：1s 时钟；媒体有播放时 500ms 进度；通知 hydrate 一次；封面 sourceSize 小

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    property bool unlocking: false
    property bool failed: false
    property bool dismissing: false

    signal submit()

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

    readonly property var player: Media.active
    readonly property bool hasMedia: !!player
    readonly property string trackTitle: player ? (player.trackTitle || "未知曲目") : ""
    readonly property string trackArtist: player ? (player.trackArtist || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property real trackLength: player ? (Number(player.length) || 0) : 0
    readonly property bool isPlaying: !!(player && player.isPlaying)
    readonly property bool canSeek: !!(player && player.canSeek)

    property real seekPos: 0
    property bool seeking: false

    // hydrate 灌 entries；锁屏只读快照，不设 uiActive
    readonly property var notifRows: {
        const list = Notification.entries || []
        const out = []
        const n = Math.min(list.length, 4)
        for (let i = 0; i < n; i++) {
            const e = list[i]
            if (!e)
                continue
            out.push({
                appName: e.appName || "",
                summary: e.summary || "",
                body: e.body || ""
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

    // —— 玻璃面板壳（无 title 栏）——
    component Glass: Rectangle {
        radius: Size.rounding.xl
        color: Color.withAlpha(Color.surfaceHigh, 0.78)
        border.width: Style.border.width
        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
    }

    // ========== 左上：天气 ==========
    Glass {
        id: weatherPane
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Size.spacing.xl
        anchors.topMargin: Size.spacing.xl
        width: weatherInner.implicitWidth + 36
        height: weatherInner.implicitHeight + 28
        z: 2

        Row {
            id: weatherInner
            anchors.centerIn: parent
            spacing: 14

            Image {
                width: 52
                height: 52
                anchors.verticalCenter: parent.verticalCenter
                source: Weather.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                sourceSize.width: 96
                sourceSize.height: 96
                visible: Weather.ready && status === Image.Ready
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Weather.ready ? Weather.tempText : "--"
                    color: Color.text
                    font.family: Size.fontMono
                    font.pixelSize: 36
                    font.weight: Font.Light
                }
                Text {
                    text: Weather.ready
                        ? (Weather.weatherText || Weather.locationName || "")
                        : "天气加载中"
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                }
                Text {
                    visible: Weather.ready && Weather.locationName.length > 0
                        && Weather.weatherText.length > 0
                    text: Weather.locationName
                    color: Color.withAlpha(Color.textMuted, 0.85)
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                }
            }
        }
    }

    // ========== 右上：通知 ==========
    Glass {
        id: notifPane
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Size.spacing.xl
        anchors.topMargin: Size.spacing.xl
        width: Math.min(300, parent.width * 0.32)
        visible: root.notifRows.length > 0
        height: notifCol.implicitHeight + 28
        z: 2

        Column {
            id: notifCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 12

            Text {
                text: "通知"
                color: Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.xsm
                font.letterSpacing: 1.2
            }

            Repeater {
                model: root.notifRows
                delegate: Column {
                    width: notifCol.width
                    spacing: 3

                    Text {
                        width: parent.width
                        text: modelData.appName || "应用"
                        color: Color.primary
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.summary || ""
                        color: Color.text
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.sm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                    Text {
                        width: parent.width
                        visible: (modelData.body || "").length > 0
                            && modelData.body !== modelData.summary
                        text: modelData.body || ""
                        color: Color.textMuted
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: index < root.notifRows.length - 1
                        color: Color.withAlpha(Color.outlineVariant, 0.35)
                    }
                }
            }
        }
    }

    // ========== 中轴：时钟 + 密码 ==========
    Column {
        id: centerCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.04
        width: Math.min(440, parent.width - 120)
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._timeStr
            color: Color.text
            font.pixelSize: Math.min(120, Math.round(parent.width * 0.28))
            font.family: Size.fontMono
            font.weight: Font.ExtraLight
            opacity: 0.96
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._dateStr
            color: Color.textMuted
            font.pixelSize: Size.fontSize.lg
            font.family: Size.fontSans
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            width: parent.width
            height: 20
        }

        // 密码：居中胶囊，不是「带标题的卡片」
        Item {
            width: Math.min(360, parent.width)
            height: 56
            anchors.horizontalCenter: parent.horizontalCenter
            transform: Translate { id: pwdShake; x: 0 }

            Rectangle {
                id: pwdShell
                anchors.fill: parent
                radius: height / 2
                color: Color.withAlpha(Color.surfaceHighest, 0.88)
                border.width: 2
                border.color: root.failed
                    ? Color.error
                    : (pwdInput.activeFocus
                        ? Color.primary
                        : Color.withAlpha(Color.outlineVariant, 0.5))

                Behavior on border.color { CAnim {} }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 18
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "lock"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                        color: root.failed ? Color.error : Color.textMuted
                    }

                    TextInput {
                        id: pwdInput
                        width: parent.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        color: Color.text
                        font.pixelSize: Size.fontSize.lg
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

                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: !pwdInput.text
                            text: root.unlocking ? "验证中…" : (root.failed ? "密码错误" : "输入密码")
                            color: root.failed ? Color.error : Color.textMuted
                            font: pwdInput.font
                        }
                    }
                }
            }
        }
    }

    // 装饰性/刷新动画，不走令牌（plan.md 白名单）：密码错误抖动，40–60ms 短档位手写关键帧
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: pwdShake; property: "x"; to: 14; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -12; duration: 50 }
        NumberAnimation { target: pwdShake; property: "x"; to: 8; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: -6; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: 0; duration: 40 }
    }

    // ========== 底栏方案 B：单行居中（封面|曲目/进度|三键|音量）==========
    // 不吃满宽度；无第二行全宽音量条；无播放时收成音量短条
    Glass {
        id: bottomBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Size.spacing.xl
        width: root.hasMedia
            ? Math.min(parent.width * 0.72, 780)
            : Math.min(parent.width * 0.36, 320)
        height: root.hasMedia ? 76 : 56
        radius: height / 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.hasMedia ? 12 : 16
            anchors.rightMargin: 16
            spacing: 12

            // 封面
            Rectangle {
                visible: root.hasMedia
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: width / 2
                color: Color.surfaceHighest
                clip: true

                scale: root.isPlaying ? 1.0 : 0.94
                Behavior on scale {
                    Anim { type: Anim.Spatial }
                }

                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 104
                    sourceSize.height: 104
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready
                    text: "music_note"
                    color: Color.textMuted
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.lg
                }
            }

            // 曲目 + 进度
            ColumnLayout {
                visible: root.hasMedia
                Layout.fillWidth: true
                Layout.minimumWidth: 80
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: Color.text
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist.length
                        ? root.trackArtist
                        : (Media.activeIdentity || "")
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    height: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Color.withAlpha(Color.text, 0.12)

                        Rectangle {
                            height: parent.height
                            width: parent.width * (
                                root.trackLength > 0
                                    ? Math.max(0, Math.min(1, root.seekPos / root.trackLength))
                                    : 0
                            )
                            radius: parent.radius
                            color: Color.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        enabled: root.canSeek && root.trackLength > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
            }

            // 三键：上一 / 播放 / 下一
            Row {
                visible: root.hasMedia
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                LockMediaBtn {
                    glyph: "skip_previous"
                    onTriggered: {
                        if (root.player)
                            root.player.previous()
                    }
                }
                LockMediaBtn {
                    glyph: root.isPlaying ? "pause" : "play_arrow"
                    primary: true
                    onTriggered: {
                        if (root.player)
                            root.player.togglePlaying()
                    }
                }
                LockMediaBtn {
                    glyph: "skip_next"
                    onTriggered: {
                        if (root.player)
                            root.player.next()
                    }
                }
            }

            Rectangle {
                visible: root.hasMedia
                Layout.preferredWidth: 1
                Layout.preferredHeight: 28
                color: Color.withAlpha(Color.outlineVariant, 0.4)
            }

            // 内嵌音量（短滑条，不另起一行）
            RowLayout {
                Layout.preferredWidth: root.hasMedia ? 128 : -1
                Layout.fillWidth: !root.hasMedia
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: width / 2
                    color: volMuteMa.containsMouse
                        ? Color.withAlpha(Color.text, 0.1)
                        : "transparent"
                    opacity: Volume.hasSink ? 1 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: root.volIcon
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                        color: Volume.sinkMuted ? Color.error : Color.text
                    }
                    MouseArea {
                        id: volMuteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Volume.hasSink
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Volume.toggleSinkMute()
                    }
                }

                QslSlider {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    value: Volume.sinkVolume
                    muted: Volume.sinkMuted
                    enabled: Volume.hasSink
                    onMoved: (v) => Volume.setSinkVolume(v)
                }
            }
        }
    }

    component LockMediaBtn: Rectangle {
        id: btn
        property string glyph: ""
        property bool primary: false
        signal triggered()

        width: primary ? 40 : 32
        height: primary ? 40 : 32
        radius: width / 2
        color: primary
            ? Color.primary
            : (ma.containsMouse ? Color.surfaceHighest : Color.withAlpha(Color.surfaceHighest, 0.45))
        opacity: enabled ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: primary ? Color.textOnPrimary : Color.text
            font.family: Size.fontIcon
            font.pixelSize: primary ? Size.fontSize.lg : Size.fontSize.md
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    property string _timeStr: ""
    property string _dateStr: ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            root._timeStr = now.toLocaleTimeString(Qt.locale(), "HH:mm")
            root._dateStr = now.toLocaleDateString(Qt.locale(), "dddd · M月d日")
        }
    }

    // 仅有媒体时刷新进度（500ms，轻于 Hub 的 200ms）
    Timer {
        interval: 500
        running: root.hasMedia && !root.dismissing
        repeat: true
        onTriggered: {
            if (!root.seeking && root.player)
                root.seekPos = Number(root.player.position) || 0
        }
    }

    Component.onCompleted: {
        Notification.hydrate()
        Weather.ensureDaemon()
        pwdInput.forceActiveFocus()
    }

    Component.onDestruction: {
        // 锁屏只借 entries 展示；通知中心未开时清掉，避免单例常驻
        if (!Notification.uiActive)
            Notification.release()
    }
}
