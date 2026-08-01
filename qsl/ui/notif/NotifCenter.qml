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
    // 收起态行高。展开态由正文实际行数决定，见 delegate 的 expandedH。
    readonly property int rowHeight: 84
    readonly property int rowIconSize: 44
    // 展开时正文最多显示多少行；再长就 elide，避免一条通知吃满整个面板
    readonly property int expandedBodyLines: 12
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
                            clip: true

                            property bool exiting: false
                            property bool expanded: false
                            // 单条收起要收行高；清空波次只滑不收高（否则 ListView 狂刷布局）
                            property bool shrinking: false
                            // 回收池换数据时高度会瞬变，此刻必须关掉动画
                            property bool animateHeight: false
                            property int notifId: modelData.notifId

                            // 正文展开后由文本实际高度撑开；至少不低于收起态
                            readonly property int expandedH:
                                Math.max(root.rowHeight,
                                         textCol.implicitHeight + Size.spacing.md * 2)

                            height: shrinking ? 0 : (expanded ? expandedH : root.rowHeight)

                            Behavior on height {
                                enabled: row.animateHeight
                                NumberAnimation {
                                    duration: Size.anim.normal
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // 正文/标题没被截断就没有可展开的内容，不给交互暗示
                            readonly property bool canExpand:
                                row.expanded || bodyText.truncated || summaryText.truncated

                            function toggleExpand() {
                                if (!canExpand)
                                    return
                                animateHeight = true
                                expanded = !expanded
                            }

                            function resetVisual() {
                                exitAnim.stop()
                                exitDelay.stop()
                                // 先关动画再改状态，避免复用时从上一条的高度插值过来
                                animateHeight = false
                                exiting = false
                                shrinking = false
                                expanded = false
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
                                if (thenDismiss) {
                                    animateHeight = true
                                    shrinking = true
                                }
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
                                // 跟 row 走：展开时一起长高，收起单条时一起收到 0
                                height: row.height
                                radius: Size.rounding.lg
                                color: rowMa.containsMouse || row.expanded
                                    ? Color.withAlpha(Color.surfaceHighest, 0.7)
                                    : Color.withAlpha(Color.surfaceHighest, 0.35)

                                // anchors 布局：避免 RowLayout/ColumnLayout 把子项纵向撑开贴底
                                readonly property int pad: Size.spacing.md

                                Rectangle {
                                    id: iconBox
                                    width: root.rowIconSize
                                    height: root.rowIconSize
                                    anchors.left: parent.left
                                    anchors.leftMargin: body.pad
                                    // 展开后卡片可能很高，图标浮在正中间会很怪，改为贴顶
                                    anchors.verticalCenter: row.expanded ? undefined : parent.verticalCenter
                                    anchors.top: row.expanded ? parent.top : undefined
                                    anchors.topMargin: Size.spacing.md
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
                                        sourceSize.width: root.rowIconSize
                                        sourceSize.height: root.rowIconSize
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

                                // 右侧动作区：展开指示 + 关闭。整块跟着图标一起贴顶，
                                // 否则展开后关闭按钮会掉到卡片正中间。
                                Row {
                                    id: actions
                                    anchors.right: parent.right
                                    anchors.rightMargin: body.pad
                                    anchors.verticalCenter: row.expanded ? undefined : parent.verticalCenter
                                    anchors.top: row.expanded ? parent.top : undefined
                                    anchors.topMargin: Size.spacing.md
                                    spacing: Size.spacing.sm

                                    Text {
                                        id: expandBtn
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\uf078"
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.xsm
                                        color: Color.textMuted
                                        // 必须用 opacity 而非 visible：Row 的隐式宽度会跳过不可见子项，
                                        // 一旦 visible 绑到 canExpand 就成环——
                                        // actions.width → textCol.width → bodyText.truncated → canExpand。
                                        opacity: row.canExpand && !root.clearing ? 1 : 0
                                        rotation: row.expanded ? 180 : 0
                                        Behavior on rotation {
                                            NumberAnimation {
                                                duration: Size.anim.normal
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Text {
                                        id: closeBtn
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
                                }

                                Column {
                                    id: textCol
                                    anchors.left: iconBox.right
                                    anchors.leftMargin: Size.spacing.md
                                    anchors.right: actions.left
                                    anchors.rightMargin: Size.spacing.sm
                                    anchors.verticalCenter: row.expanded ? undefined : parent.verticalCenter
                                    anchors.top: row.expanded ? parent.top : undefined
                                    anchors.topMargin: Size.spacing.md
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
                                        id: summaryText
                                        width: parent.width
                                        text: modelData.summary || "(无标题)"
                                        color: Color.text
                                        font.pixelSize: Size.fontSize.md
                                        font.bold: true
                                        elide: row.expanded ? Text.ElideNone : Text.ElideRight
                                        wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                                        maximumLineCount: row.expanded ? 3 : 1
                                    }
                                    Text {
                                        id: bodyText
                                        width: parent.width
                                        text: modelData.body || ""
                                        color: Color.textMuted
                                        font.pixelSize: Size.fontSize.sm
                                        // 展开态刻意不用 elide：elide 需要先知道 height 才能决定截断量，
                                        // 而这里 height 又绑到 implicitHeight，两者会互相拉成环。
                                        // 收起态 height 是常量，用 elide 安全。
                                        elide: row.expanded ? Text.ElideNone : Text.ElideRight
                                        wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                                        maximumLineCount: row.expanded ? root.expandedBodyLines : 1
                                        // 单行高度用字号推算，避开 height↔implicitHeight 环
                                        height: text.length === 0
                                            ? 0
                                            : (row.expanded
                                               ? Math.ceil(implicitHeight)
                                               : Math.ceil(font.pixelSize * 1.35))
                                        visible: text.length > 0
                                    }
                                }

                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    // 整卡点击折叠；z:-1 让关闭按钮优先拿到事件
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: row.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: !row.exiting && !root.clearing
                                    onClicked: row.toggleExpand()
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
