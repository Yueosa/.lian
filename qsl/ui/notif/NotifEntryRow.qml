// NotifEntryRow — 详情页的一条通知：图标 + 应用名/时间 + 标题/正文 + 展开/关闭
//
// 第 10 轮拆分从 NotifListCard 摘出来（原 536 行，这个 delegate 一个人占 287 行）。
// 三件互相纠缠的事——展开收拢、单条关闭、清空波次——连同各自的动画、Timer 和
// 回收钩子整块搬过来，边界一处没动。搬家时特意**没有**合并的两件事：
//   1. 退出动画（右滑淡出）和高度收拢是两套。单条关闭才收 height，
//      清空波次只滑不收高，否则 ListView 会被一波高度变化刷到抽筋。
//   2. 关闭传的是 entry 整条，Notification.dismiss 取的是数据库唯一 id，
//      不是可复用的 D-Bus notifId——第 9 轮踩过「关一条连带关一批」。
//
// 跟卡根的接口：
//   card      —— 回引 NotifListCard，取 sharedState / rowHeight / rowIconSize /
//                expandedBodyLines
//   entry     —— 本行的通知数据，卡根在 delegate 处用 required modelData 传进来
//   rowIndex  —— 行序号，清空错峰按它排队（同上，来自 required index）

import QtQuick
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: row

    property Item card: null
    property var entry: null
    property int rowIndex: -1

    // 下面读它十来次，写全 card.sharedState.xxx 太长
    readonly property QtObject shared: card.sharedState

    width: ListView.view ? ListView.view.width : 0
    clip: true

    property bool exiting: false
    property bool expanded: false
    // 单条收起要收行高；清空波次只滑不收高（否则 ListView 狂刷布局）
    property bool shrinking: false
    // 回收池换数据时高度会瞬变，此刻必须关掉动画
    property bool animateHeight: false
    // 正文展开后由文本实际高度撑开；至少不低于收起态
    readonly property int expandedH:
        Math.max(row.card.rowHeight,
                 textCol.implicitHeight + Size.spacing.md * 2)

    height: shrinking ? 0 : (expanded ? expandedH : row.card.rowHeight)

    Behavior on height {
        enabled: row.animateHeight
        Anim { type: Anim.Spatial }
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
        if (row.shared.clearing && thenDismiss)
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

    readonly property string iconSrc: Notification.iconFor(row.entry)

    ListView.onPooled: resetVisual()
    ListView.onReused: resetVisual()

    Connections {
        target: row.shared
        function onClearingChanged() {
            if (!row.shared.clearing || row.exiting)
                return
            if (row.rowIndex >= row.shared.clearAnimMax)
                return
            exitDelay.interval = row.rowIndex * row.shared.clearStaggerMs
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
        Anim {
            target: body; property: "x"
            to: row.width; type: Anim.Spatial
        }
        Anim {
            target: body; property: "opacity"
            to: 0; type: Anim.EffectsFast
        }
        onFinished: {
              if (thenDismiss)
                  Notification.dismiss(row.entry)
        }
    }

    Rectangle {
        id: body
        width: parent.width
        height: row.height
        radius: Size.rounding.lg
        color: Color.withAlpha(Color.surfaceContainerHighest, 0.35)

        // 展开的那条一直亮着，且比悬停重一档——原来两者同色，
        // 鼠标划过去时分不清哪条是展开的
        QslStateLayer { source: rowMa; selected: row.expanded }

        // anchors 布局：避免 RowLayout/ColumnLayout 把子项纵向撑开贴底
        readonly property int pad: Size.spacing.md

        Rectangle {
            id: iconBox
            width: row.card.rowIconSize
            height: row.card.rowIconSize
            anchors.left: parent.left
            anchors.leftMargin: body.pad
            // 展开后卡片可能很高，图标浮在正中间会很怪，改为贴顶
            anchors.verticalCenter: row.expanded ? undefined : parent.verticalCenter
            anchors.top: row.expanded ? parent.top : undefined
            anchors.topMargin: Size.spacing.md
            radius: Size.rounding.md
            color: Color.primaryContainer
            clip: true

            Image {
                id: appImg
                anchors.fill: parent
                anchors.margins: 4
                source: row.iconSrc
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: row.card.rowIconSize
                sourceSize.height: row.card.rowIconSize
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: appImg.status !== Image.Ready
                text: "\uf0f3"
                font.family: Size.fontMono
                font.pixelSize: Size.iconSize.lg
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
                font.pixelSize: Size.iconSize.xs
                color: Color.textMuted
                // 必须用 opacity 而非 visible：Row 的隐式宽度会跳过不可见子项，
                // 一旦 visible 绑到 canExpand 就成环——
                // actions.width → textCol.width → bodyText.truncated → canExpand。
                opacity: row.canExpand && !row.shared.clearing ? 1 : 0
                rotation: row.expanded ? 180 : 0
                Behavior on rotation {
                    Anim { type: Anim.Spatial }
                }
            }

            Text {
                id: closeBtn
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00d"
                font.family: Size.fontMono
                font.pixelSize: Size.iconSize.sm
                color: Color.textMuted
                opacity: row.shared.clearing ? 0.3 : 1
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    enabled: !row.exiting && !row.shared.clearing
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
                    text: row.entry.appName || "系统"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.labelSmall
                    elide: Text.ElideRight
                }
                Text {
                    id: timeLabel
                    text: row.relativeTime(row.entry.receivedAt)
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.labelSmall
                }
            }
            Text {
                id: summaryText
                width: parent.width
                text: row.entry.summary || "(无标题)"
                color: Color.text
                font.pixelSize: Size.fontSize.titleSmall
                font.bold: true
                elide: row.expanded ? Text.ElideNone : Text.ElideRight
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: row.expanded ? 3 : 1
            }
            Text {
                id: bodyText
                width: parent.width
                text: row.entry.body || ""
                color: Color.textMuted
                font.pixelSize: Size.fontSize.bodySmall
                // 展开态刻意不用 elide：elide 需要先知道 height 才能决定截断量，
                // 而这里 height 又绑到 implicitHeight，两者会互相拉成环。
                // 收起态 height 是常量，用 elide 安全。
                elide: row.expanded ? Text.ElideNone : Text.ElideRight
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: row.expanded ? row.card.expandedBodyLines : 1
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
            enabled: !row.exiting && !row.shared.clearing
            onClicked: row.toggleExpand()
            z: -1
        }
    }
}
