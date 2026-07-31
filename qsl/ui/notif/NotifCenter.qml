// NotifCenter — 右下角通知中心（轻量版）
// 开栏全屏 mask：点空白关闭；关栏 mask=0
// 无 gooey；圆角卡片 + 面板 slide；单条右滑淡出
// 清空：仅前 clearAnimMax 条错开滑出，其余随 dismissAll 消失
// 无空态文案（关窗 release 时不闪「没有新通知」）
//
// 性能：清空最多 5 路并行动画且不清行高；单条才收 height

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.data.state
import qs.data.service

PanelWindow {
    id: root

    color: "transparent"
    // 关态也保持 visible：卸 layer 会在 IPC 开栏时同步建缓冲卡顿
    visible: true

    // 开栏铺满，点空白关闭；关栏 mask=0
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    exclusiveZone: 0

    WlrLayershell.namespace: "qsl-notif"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property bool open: false
    property bool clearing: false
    readonly property int panelWidth: 420
    readonly property int rowHeight: 72
    readonly property int closedOffset: Math.round(Math.min(640, Screen.height - 48) + 80)
    readonly property bool contentActive: open || anim.slide !== closedOffset

    function toggle() { open ? closeWindow() : openWindow() }
    function openWindow() {
        clearFinish.stop()
        clearing = false
        if (!open)
            Island.captureFocus()
        open = true
        Notification.uiActive = true
        Notification.hydrate()
        Notification.refresh()
    }
    function closeWindow() {
        if (!open)
            return
        open = false
        Notification.uiActive = false
        Island.restoreFocus()
    }

    // 清空：只让前 clearAnimMax 条错开右滑，其余直接随 dismissAll 消失
    // （后面那些本来也多在屏外；限制并发动画避免后半段卡顿）
    readonly property int clearAnimMax: 5
    readonly property int clearStaggerMs: 30

    function clearAllAnimated() {
        if (clearing || !Notification.hasNotifications)
            return
        clearing = true
        const n = Math.min(listView.count, clearAnimMax)
        clearFinish.interval = Size.anim.normal + 50 + Math.max(0, n - 1) * clearStaggerMs
        clearFinish.restart()
    }

    Timer {
        id: clearFinish
        repeat: false
        onTriggered: {
            Notification.dismissAll()
            root.clearing = false
            root.closeWindow()
        }
    }

    onContentActiveChanged: {
        if (!contentActive) {
            Notification.uiActive = false
            Notification.release()
        }
    }

    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    Item {
        id: anim
        property int slide: root.closedOffset
        state: root.open ? "open" : "closed"
        states: [
            State { name: "open"; PropertyChanges { target: anim; slide: 0 } },
            State { name: "closed"; PropertyChanges { target: anim; slide: root.closedOffset } }
        ]
        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: anim; property: "slide"
                    duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.25
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: anim; property: "slide"
                    duration: 280; easing.type: Easing.InBack; easing.overshoot: 0.08
                }
            }
        ]
    }

    FocusScope {
        anchors.fill: parent
        enabled: root.open
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
                event.accepted = true
            }
        }

        // 点空白关（面板外）
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }

        Rectangle {
            id: card
            width: root.panelWidth
            height: Math.min(Math.min(640, root.height - 48) - 24, Math.max(280, listCol.implicitHeight + 88))
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 16
            anchors.bottomMargin: 16 - anim.slide
            visible: root.contentActive
            radius: Size.rounding.xl
            // 对齐 Hub：实色 background
            color: Color.background
            border.width: 2
            border.color: Color.secondaryFixed
            clip: true

            // 吃掉点击，避免穿透到空白 MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: listCol
                anchors.fill: parent
                anchors.margins: Size.spacing.lg
                spacing: Size.spacing.md

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.sm

                    Text {
                        text: "通知中心"
                        color: Color.text
                        font.pixelSize: Size.fontSize.lg
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    // 免打扰
                    Rectangle {
                        width: 32; height: 32
                        radius: Size.rounding.full
                        color: dndMa.containsMouse
                            ? Color.withAlpha(Color.primary, 0.18)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: Notification.dndEnabled ? "\uf1f6" : "\uf0f3"
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.md
                            color: Notification.dndEnabled ? Color.secondary : Color.text
                        }
                        MouseArea {
                            id: dndMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notification.toggleDnd()
                        }
                    }

                    // 清空
                    Rectangle {
                        width: 32; height: 32
                        radius: Size.rounding.full
                        color: clearMa.containsMouse
                            ? Color.withAlpha(Color.error, 0.18)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "\uf1f8"
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.md
                            color: Notification.hasNotifications ? Color.error : Color.textMuted
                            opacity: Notification.hasNotifications ? 1 : 0.4
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: Notification.hasNotifications && !root.clearing
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.clearAllAnimated()
                        }
                    }
                    // 关窗：Esc / 点外侧（与 Rightbar 一致，无 X）
                }

                Item {
                    id: listSlide
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        clip: true
                        spacing: Size.spacing.sm
                        model: Notification.entries
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds

                        // 无空态文案：关窗 release() 会清空 entries，避免闪「没有新通知」

                        delegate: Item {
                            id: row
                            width: ListView.view ? ListView.view.width : 0
                            height: root.rowHeight
                            clip: true

                            property bool exiting: false
                            property int notifId: modelData.notifId

                            Behavior on height {
                                enabled: row.exiting
                                NumberAnimation {
                                    duration: Size.anim.normal
                                    easing.type: Easing.InQuad
                                }
                            }

                            function resetVisual() {
                                exitAnim.stop()
                                exitDelay.stop()
                                exiting = false
                                height = root.rowHeight
                                body.x = 0
                                body.opacity = 1
                            }

                            // thenDismiss=true：单条关闭（收行高 + dismiss）
                            // thenDismiss=false：清空波次（只滑不收高，避免 ListView 狂刷布局）
                            function beginExit(thenDismiss) {
                                if (exiting)
                                    return
                                if (root.clearing && thenDismiss)
                                    return
                                exiting = true
                                if (thenDismiss)
                                    height = 0
                                exitAnim.thenDismiss = !!thenDismiss
                                exitAnim.start()
                            }

                            function relativeTime(ms) {
                                if (!ms)
                                    return ""
                                const sec = Math.max(0, Math.floor((Date.now() - ms) / 1000))
                                if (sec < 60)
                                    return "刚刚"
                                if (sec < 3600)
                                    return Math.floor(sec / 60) + " 分钟前"
                                if (sec < 86400)
                                    return Math.floor(sec / 3600) + " 小时前"
                                return Math.floor(sec / 86400) + " 天前"
                            }

                            readonly property string iconSrc: {
                                const p = modelData.imagePath || ""
                                if (!p)
                                    return ""
                                // qsimage 句柄随进程失效；DB/缓存里残留的直接丢掉走 fallback 字标
                                if (p.indexOf("image://qsimage") === 0)
                                    return ""
                                if (p.startsWith("file://") || p.startsWith("image://"))
                                    return p
                                if (p.startsWith("/"))
                                    return "file://" + p
                                return "image://icon/" + p
                            }

                            ListView.onPooled: resetVisual()
                            ListView.onReused: resetVisual()

                            Connections {
                                target: root
                                function onClearingChanged() {
                                    if (!root.clearing || row.exiting)
                                        return
                                    if (index >= root.clearAnimMax)
                                        return
                                    exitDelay.interval = index * root.clearStaggerMs
                                    exitDelay.start()
                                }
                            }

                            Timer {
                                id: exitDelay
                                repeat: false
                                onTriggered: row.beginExit(false)
                            }

                            ParallelAnimation {
                                id: exitAnim
                                property bool thenDismiss: false
                                NumberAnimation {
                                    target: body; property: "x"
                                    to: row.width; duration: Size.anim.normal
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    target: body; property: "opacity"
                                    to: 0; duration: Size.anim.fast
                                    easing.type: Easing.InQuad
                                }
                                onFinished: {
                                    if (thenDismiss)
                                        Notification.dismiss(row.notifId)
                                }
                            }

                            Rectangle {
                                id: body
                                width: parent.width
                                height: root.rowHeight
                                radius: Size.rounding.lg
                                color: rowMa.containsMouse
                                    ? Color.withAlpha(Color.surfaceHighest, 0.7)
                                    : Color.withAlpha(Color.surfaceHighest, 0.35)

                                // anchors 布局：避免 RowLayout/ColumnLayout 把子项纵向撑开贴底
                                readonly property int pad: Size.spacing.md

                                Rectangle {
                                    id: iconBox
                                    width: 40
                                    height: 40
                                    anchors.left: parent.left
                                    anchors.leftMargin: body.pad
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: Size.rounding.md
                                    color: Color.withAlpha(Color.primary, 0.15)
                                    clip: true

                                    Image {
                                        id: appImg
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: row.iconSrc
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: false
                                        sourceSize.width: 40
                                        sourceSize.height: 40
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: appImg.status !== Image.Ready
                                        text: "\uf0f3"
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.lg
                                        color: Color.primary
                                    }
                                }

                                Text {
                                    id: closeBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: body.pad
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uf00d"
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.sm
                                    color: Color.textMuted
                                    opacity: root.clearing ? 0.3 : 1
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        enabled: !row.exiting && !root.clearing
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: row.beginExit(true)
                                    }
                                }

                                Column {
                                    id: textCol
                                    anchors.left: iconBox.right
                                    anchors.leftMargin: Size.spacing.md
                                    anchors.right: closeBtn.left
                                    anchors.rightMargin: Size.spacing.sm
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Row {
                                        width: parent.width
                                        spacing: Size.spacing.sm
                                        Text {
                                            width: parent.width - timeLabel.width - parent.spacing
                                            text: modelData.appName || "系统"
                                            color: Color.textMuted
                                            font.pixelSize: Size.fontSize.xsm
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            id: timeLabel
                                            text: row.relativeTime(modelData.receivedAt)
                                            color: Color.textMuted
                                            font.pixelSize: Size.fontSize.xsm
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.summary || "(无标题)"
                                        color: Color.text
                                        font.pixelSize: Size.fontSize.md
                                        font.bold: true
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.body || ""
                                        color: Color.textMuted
                                        font.pixelSize: Size.fontSize.sm
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                        // 单行高度用字号推算，避开 height↔implicitHeight 环
                                        //（elide 时 Text 的 implicitHeight 会跟 height 互相拉）
                                        height: text.length > 0 ? Math.ceil(font.pixelSize * 1.35) : 0
                                        visible: text.length > 0
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    z: -1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
