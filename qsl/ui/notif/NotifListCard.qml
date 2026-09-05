// NotifListCard — 应用列表 ↔ 应用详情 横向滑动双 ListView（N 页两容器之二）
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
//
// 两页横向滑动：左=应用列表，右=某应用的通知。
// 两个 ListView 都常驻，切页只动 x——重建 delegate 会丢滚动位置，
// 而且回收池要重新填充，来回切几次就明显卡。
// 清空：两级列表的行都有退出动画（onClearingChanged → exitDelay → 右滑淡出），
// 只让前 clearAnimMax 条错开滑出，其余随 dismissAll 消失
// 无空态文案（关窗 release 时不闪「没有新通知」）
//
// 性能：清空最多 5 路并行动画且不清行高；单条才收 height；ListView reuseItems

import QtQuick
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    // 固定吃屏高 72%（旧版 640 封顶太矮）；高度不随内容变，清空/过滤不跳高
    implicitHeight: sharedState ? sharedState.listHeight : 0

    // 指向 NotifCenter.notifState（currentApp / clearing / 分组聚合 / 图标回退）
    // 不叫 state：Item 自带同名属性（状态机当前态），避免遮蔽
    property QtObject sharedState

    // 收起态行高。展开态由正文实际行数决定，见 delegate 的 expandedH。
    readonly property int rowHeight: 84
    readonly property int rowIconSize: 44
    // 展开时正文最多显示多少行；再长就 elide，避免一条通知吃满整个列表
    readonly property int expandedBodyLines: 12
    readonly property int appRowHeight: 68

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Item {
        id: listSlide
        anchors.fill: parent
        anchors.margins: Size.spacing.lg
        clip: true

        property real pageShift: root.sharedState.currentApp === "" ? 0 : -width
        Behavior on pageShift {
            Anim { type: Anim.Spatial }
        }

        // ---------- 应用列表页 ----------
        ListView {
            id: appListView
            width: parent.width
            height: parent.height
            x: listSlide.pageShift
            clip: true
            spacing: Size.spacing.xs
            model: root.sharedState.appGroups
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            // 滑出去之后别再吃事件
            enabled: root.sharedState.currentApp === ""

            delegate: Item {
                id: appRow
                width: ListView.view ? ListView.view.width : 0
                height: root.appRowHeight
                clip: true

                property bool exiting: false

                function resetVisual() {
                    exitAnim.stop()
                    exitDelay.stop()
                    exiting = false
                    appBody.x = 0
                    appBody.opacity = 1
                }

                // 只有清空波次会调（应用行没有单条关闭钮），只滑不收高
                function beginExit() {
                    if (exiting)
                        return
                    exiting = true
                    exitAnim.start()
                }

                ListView.onPooled: resetVisual()
                ListView.onReused: resetVisual()

                // 与详情列表同款清空退出：错开向右滑出（N 在 rightrail 上，
                // 往右滑 = 收回 rail 方向）
                Connections {
                    target: root.sharedState
                    function onClearingChanged() {
                        if (!root.sharedState.clearing || appRow.exiting)
                            return
                        if (index >= root.sharedState.clearAnimMax)
                            return
                        exitDelay.interval = index * root.sharedState.clearStaggerMs
                        exitDelay.start()
                    }
                }

                Timer {
                    id: exitDelay
                    repeat: false
                    onTriggered: appRow.beginExit()
                }

                ParallelAnimation {
                    id: exitAnim
                    Anim {
                        target: appBody; property: "x"
                        to: appRow.width; type: Anim.Spatial
                    }
                    Anim {
                        target: appBody; property: "opacity"
                        to: 0; type: Anim.EffectsFast
                    }
                }

                Rectangle {
                    id: appBody
                    width: appRow.width
                    height: appRow.height - 4
                    y: 2
                    radius: Size.rounding.lg
                    color: Color.withAlpha(Color.surfaceContainerHighest, 0.35)

                    QslStateLayer { source: appMa }

                    Rectangle {
                        id: appIconBox
                        width: root.rowIconSize
                        height: root.rowIconSize
                        anchors.left: parent.left
                        anchors.leftMargin: Size.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        radius: Size.rounding.md
                        color: Color.withAlpha(Color.primary, 0.15)
                        clip: true

                        Image {
                            id: appGroupImg
                            anchors.fill: parent
                            anchors.margins: 4
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            sourceSize.width: root.rowIconSize
                            sourceSize.height: root.rowIconSize
                            visible: status === Image.Ready
                        }
                        // 没图标就用应用名首字，比统一的铃铛好认
                        Text {
                            anchors.centerIn: parent
                            visible: appGroupImg.status !== Image.Ready
                            text: (modelData.name || "?").charAt(0).toUpperCase()
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.titleMedium
                            font.bold: true
                            color: Color.primary
                        }
                    }

                    Rectangle {
                        id: countPill
                        anchors.right: parent.right
                        anchors.rightMargin: Size.spacing.md
                        anchors.verticalCenter: parent.verticalCenter
                        width: countLabel.implicitWidth + Size.spacing.md
                        height: 24
                        radius: Size.rounding.full
                        color: Color.withAlpha(Color.primary, 0.20)
                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: modelData.count + " 条"
                            color: Color.primary
                            font.pixelSize: Size.fontSize.labelSmall
                            font.bold: true
                        }
                    }

                    Column {
                        anchors.left: appIconBox.right
                        anchors.leftMargin: Size.spacing.md
                        anchors.right: countPill.left
                        anchors.rightMargin: Size.spacing.sm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: modelData.name
                            color: Color.text
                            font.pixelSize: Size.fontSize.titleSmall
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            width: parent.width
                            text: modelData.preview
                            color: Color.textMuted
                            font.pixelSize: Size.fontSize.bodySmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            height: text.length > 0 ? Math.ceil(font.pixelSize * 1.35) : 0
                            visible: text.length > 0
                        }
                    }

                    MouseArea {
                        id: appMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sharedState.openApp(modelData.key)
                    }
                }
            }
        }

        // ---------- 单应用通知页 ----------
        ListView {
            id: listView
            width: parent.width
            height: parent.height
            x: listSlide.pageShift + parent.width
            clip: true
            spacing: Size.spacing.sm
            model: root.sharedState.currentAppEntries
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            enabled: root.sharedState.currentApp !== ""

            // 无空态文案：关窗 release() 会清空 entries，避免闪「没有新通知」

            delegate: Item {
                id: row
                width: ListView.view ? ListView.view.width : 0
                clip: true

                readonly property var entry: modelData

                property bool exiting: false
                property bool expanded: false
                // 单条收起要收行高；清空波次只滑不收高（否则 ListView 狂刷布局）
                property bool shrinking: false
                // 回收池换数据时高度会瞬变，此刻必须关掉动画
                property bool animateHeight: false
                // 正文展开后由文本实际高度撑开；至少不低于收起态
                readonly property int expandedH:
                    Math.max(root.rowHeight,
                             textCol.implicitHeight + Size.spacing.md * 2)

                height: shrinking ? 0 : (expanded ? expandedH : root.rowHeight)

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
                    if (root.sharedState.clearing && thenDismiss)
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
                    target: root.sharedState
                    function onClearingChanged() {
                        if (!root.sharedState.clearing || row.exiting)
                            return
                        if (index >= root.sharedState.clearAnimMax)
                            return
                        exitDelay.interval = index * root.sharedState.clearStaggerMs
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
                            opacity: row.canExpand && !root.sharedState.clearing ? 1 : 0
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
                            opacity: root.sharedState.clearing ? 0.3 : 1
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                enabled: !row.exiting && !root.sharedState.clearing
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
                        enabled: !row.exiting && !root.sharedState.clearing
                        onClicked: row.toggleExpand()
                        z: -1
                    }
                }
            }
        }
    }
}
