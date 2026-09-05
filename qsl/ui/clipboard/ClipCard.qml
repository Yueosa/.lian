// ClipCard — Z 的唯一容器：剪贴板列表 + 贴下沿的搜索条
// 容器卡：背景/圆角/耳朵由宿主 RailContainer 提供，本卡只装内容
//
// 一张卡装两样东西（而不是像 A 那样拆两个容器）：剪贴板是"一件事"，搜索只是
// 它的取景器；拆开会多出一条缝和一拍脱离动画，读起来像两个面板。
//
// 高度弹性：列表高度 = min(内容高, sharedState.maxListH)，历史空了就只剩搜索条。
//
// 行有两种形状，选中态因此不走 ListView.highlight（那只能画一个矩形）：文本行
// 整行变色，图片行是**某一格**描边。ListView 的 currentIndex 还是要接上——
// preferredHighlight* 靠它把选中行保持在视野内。

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.clipboard
import qs.data.state

Item {
    id: root

    anchors.fill: parent

    // 指向 ClipHistory.clipState
    property QtObject sharedState

    readonly property int pad: root.sharedState ? root.sharedState.pad : 8
    readonly property int searchH: root.sharedState ? root.sharedState.searchH : 48
    // 列表内容不满上界时卡片跟着收
    readonly property int listH: root.sharedState
        ? Math.min(root.sharedState.maxListH, Math.ceil(rowList.contentHeight))
        : 0

    implicitHeight: (root.listH > 0 ? root.pad + root.listH + root.pad : 0)
        + root.searchH

    // 吃掉点击，避免穿透到 RailPage 那层「点空白关闭」
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // ============================================================
    // 列表
    // ============================================================
    ListView {
        id: rowList

        x: root.pad
        y: root.pad
        width: parent.width - 2 * root.pad
        // 视口吃父级的剩余高度，不吃 listH。listH 是目标（implicitHeight
        // 用它），父级高度由 RailContainer.displayH 缓动；这里跟 listH 就会
        // 在壳还没收到位时先跳成 1 行
        height: Math.max(0, parent.height - root.searchH
            - (root.listH > 0 ? 2 * root.pad : 0))
        clip: true

        // 增量模型（见 data/clipboard/Clipboard.qml）：搜索时留下来的行滑动、
        // 走掉的行淡出，下面那三条过渡才有东西可播
        model: Clipboard.rows
        reuseItems: true
        spacing: root.sharedState ? root.sharedState.rowSpacing : 8
        boundsBehavior: Flickable.StopAtBounds

        // 选择的真身在 sharedState（键落在搜索条上），视图只显示、不回写。
        // 回写会和绑定抢 currentIndex，症状是「按住方向键走不到头」
        // （教训见 plan-notes.md 第 7 轮 / StrictlyEnforceRange）
        currentIndex: root.sharedState ? root.sharedState.currentRow : 0
        highlight: Item {}
        highlightFollowsCurrentItem: true
        highlightMoveDuration: Size.anim.durFast
        // 上下各留一行做上下文（行高不齐，按文本行的高度当那"一行"）。
        // 夹的是高亮整块：上沿 ≥ begin、下沿 ≤ end
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: root.sharedState ? root.sharedState.textRowH : 46
        preferredHighlightEnd: height
            - (root.sharedState ? root.sharedState.textRowH : 46)

        // **只留 displaced，不要 add / remove。**
        //
        // 那两条动的是透明度，而这个列表的模型是会连着抖的（删一张图会重排整个
        // 网格、搜索每敲一个字都同步一次）。一次动画还没播完下一次模型改动就到，
        // 过渡被打断，属性就冻在中途 —— 探针实测（2026-09-05）活着的行卡在
        //   ZD model=6 items=6 [idx=1 y=120 op=0.85] [idx=2 y=174 op=0.85] …
        // 六行全停在 0.85 不回来（add 被打断，入场淡入走不到 1）。屏幕上就是一列
        // 半透明的行叠在别的东西上，得滚两下把它们收进池子才消失。
        //
        // displaced 不一样：它动的是位置，打断了下一次布局会纠正（同一份日志里
        // idx=0 y=18 下一拍就回到 y=0）。所以行级动画只留它：删掉的行立刻消失、
        // 底下的行滑上来补位，读起来反而比淡出更像"删掉了"。
        //
        // ⚠ 查这类问题别信"idx=-1 且纹丝不动"这个特征：reuseItems 回收一格走的是
        // Qt 内部的 culled 标记（渲染跳过），既不改 visible 也不摘 parent，而 index
        // 会变 -1、y 冻在最后那个位置。池子里睡着的一格和真残留在探针眼里长得一模
        // 一样，culled 在 QML 里还读不到（要分辨得自己记 onPooled/onReused）。
        // 真残留的特征是**透明度不整**（0.85 / 0.13 这种），这才是能信的那一条
        displaced: Transition {
            // 减速不过冲：一次同步会连着顶开好几格，过冲叠起来就是整列在抖
            Anim { property: "y"; type: Anim.EnterFast }
        }

        delegate: Item {
            id: rowItem

            // row 是模型的角色名：{ type: "text"|"images", entries: [...] }
            required property var row
            required property int index

            readonly property QtObject s: root.sharedState
            readonly property bool isCurrent: rowItem.s
                ? index === rowItem.s.currentRow : false
            // 粘贴动画：选中那一行留下，其余整行右滑淡出
            readonly property bool chosen: rowItem.s
                ? rowItem.s.pasting && index === rowItem.s.pasteRow : false
            readonly property bool leaving: rowItem.s
                ? rowItem.s.pasting && index !== rowItem.s.pasteRow : false

            width: rowList.width
            height: rowItem.row.type === "images"
                ? (rowItem.s ? rowItem.s.imageCellH : 112)
                : (rowItem.s ? rowItem.s.textRowH : 46)

            // 根节点的 opacity/y 归**视图**（上面那三条 Transition），别的谁都
            // 不许碰。踩过的坑：粘贴动画本来把 opacity 绑在根节点上、还挂了
            // Behavior —— 而 Behavior 是属性写入拦截器，会把 remove 过渡每一帧的
            // 写入也截下来重排一遍，那条淡出于是永远走不到 0。症状是删掉的行停在
            // 半透明不走，得滚动几下、视图把它收进池子才消失。
            // 所以淡出/右滑整个挪进内层 rowFade
            //
            // 再加一层保险：淡到 0 的 item 进池子后，被复用来画滚进视野的新行时
            // 不会走 add 过渡（那只对模型插入生效），透明度就卡在 0 —— 列表里冒出
            // 一行「什么都没有却占着位置」的空行。复用时手动收回来
            //
            ListView.onReused: rowItem.opacity = 1

            Item {
                id: rowFade

                anchors.fill: parent

                opacity: rowItem.leaving ? 0 : 1
                x: rowItem.leaving ? (rowItem.s ? rowItem.s.exitSlide : 72) : 0

                Behavior on opacity {
                    enabled: rowItem.s ? rowItem.s.animEnabled : false
                    Anim { type: Anim.Exit }
                }
                Behavior on x {
                    enabled: rowItem.s ? rowItem.s.animEnabled : false
                    Anim { type: Anim.Exit }
                }

                // ---- 文本行：整行一颗胶囊 ----
                Loader {
                    anchors.fill: parent
                    active: rowItem.row.type === "text"
                    visible: active
                    sourceComponent: Rectangle {
                        radius: Size.rounding.md
                        color: rowItem.isCurrent
                            ? Color.primary
                            : Color.withAlpha(Color.surfaceContainerHighest, 0.35)

                        Behavior on color {
                            enabled: rowItem.s ? rowItem.s.animEnabled : false
                            CAnim {}
                        }

                        MouseArea {
                            id: textHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: rowItem.s ? !rowItem.s.pasting : false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rowItem.s.pasteAt(rowItem.index, 0)
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            // 悬停时右端让出叉的位置
                            anchors.rightMargin: textHover.containsMouse ? 34 : 14
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            // 剪贴板里什么都可能有。默认的 AutoText 会把
                            // "<html><body><img src=file://...>" 认成富文本去渲染、
                            // 顺手加载里头的本地图片（日志里那串 Invalid base url in
                            // img tag 就是它）。预览一律按字面画
                            textFormat: Text.PlainText
                            text: rowItem.row.entries[0].preview || ""
                            color: rowItem.isCurrent ? Color.primaryText : Color.text
                            font.pixelSize: Size.fontSize.md
                            font.family: Size.fontSans

                            Behavior on color {
                                enabled: rowItem.s ? rowItem.s.animEnabled : false
                                CAnim {}
                            }
                        }

                        // 删这一条。只在悬停时露出：常驻的话每行右边挂一个叉，
                        // 列表读起来全是按钮
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: textHover.containsMouse
                            text: "close"
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.md
                            color: rowItem.isCurrent ? Color.primaryText : Color.textMuted

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Clipboard.remove(rowItem.row.entries[0].id)
                            }
                        }
                    }
                }

                // ---- 图片行：一行几格，选中的那格描边 ----
                Loader {
                    anchors.fill: parent
                    active: rowItem.row.type === "images"
                    visible: active
                    sourceComponent: Row {
                        spacing: rowItem.s ? rowItem.s.cellSpacing : 8

                        Repeater {
                            model: rowItem.row.entries.length

                            delegate: Rectangle {
                                id: cell

                                required property int index
                                readonly property var entry:
                                    rowItem.row.entries[cell.index]
                                readonly property bool isCurrent: rowItem.isCurrent
                                    && rowItem.s && cell.index === rowItem.s.currentCol
                                // 粘贴时同一行里没被选中的格子淡出
                                readonly property bool fading: rowItem.chosen
                                    && rowItem.s && cell.index !== rowItem.s.pasteCol

                                width: rowItem.s ? rowItem.s.imageCellW : 156
                                height: rowItem.s ? rowItem.s.imageCellH : 112
                                radius: Size.rounding.md
                                color: Color.withAlpha(Color.surfaceContainerHighest, 0.35)

                                opacity: cell.fading ? 0 : 1
                                Behavior on opacity {
                                    enabled: rowItem.s ? rowItem.s.animEnabled : false
                                    Anim { type: Anim.Exit }
                                }

                                // 圆角裁图：只在图真的到位时开图层，省一次离屏合成
                                layer.enabled: thumb.status === Image.Ready
                                layer.smooth: true
                                layer.effect: OpacityMask {
                                    maskSource: Item {
                                        width: cell.width
                                        height: cell.height
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: cell.radius
                                            color: "#000000"
                                        }
                                    }
                                }

                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    // 原比例完整可见；cell 底色做 letterbox
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    // 缓存开着：同一批 delegate 会被反复换绑（搜索、
                                    // reuseItems），关掉就是每次重解码一遍
                                    cache: true
                                    source: cell.entry.thumb
                                        ? ("file://" + cell.entry.thumb) : ""
                                    // 2× 解码，避免 HiDPI/缩放发糊（磁盘 thumb 长边 ≤384）
                                    sourceSize.width: (rowItem.s ? rowItem.s.imageCellW : 156) * 2
                                    sourceSize.height: (rowItem.s ? rowItem.s.imageCellH : 112) * 2
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !cell.entry.thumb
                                        || thumb.status !== Image.Ready
                                    text: "\uf03e"
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.xl
                                    color: Color.textMuted
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: cell.radius
                                    border.width: 3
                                    border.color: Color.primary
                                    opacity: cell.isCurrent ? 1 : 0

                                    Behavior on opacity {
                                        enabled: rowItem.s ? rowItem.s.animEnabled : false
                                        Anim { type: Anim.EffectsFast }
                                    }
                                }

                                MouseArea {
                                    id: cellHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: rowItem.s ? !rowItem.s.pasting : false
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rowItem.s.pasteAt(rowItem.index, cell.index)
                                }

                                // 图片格的叉：底下垫一层，不然浅色图上看不见
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 4
                                    width: 22
                                    height: 22
                                    radius: Size.rounding.full
                                    color: Color.withAlpha(Color.surface, 0.72)
                                    visible: cellHover.containsMouse

                                    Text {
                                        anchors.centerIn: parent
                                        text: "close"
                                        font.family: Size.fontIcon
                                        font.pixelSize: Size.fontSize.sm
                                        color: Color.text
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Clipboard.remove(cell.entry.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 搜索条（贴卡片下沿，和 A 的搜索框同高）
    // ============================================================
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.searchH
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: Size.spacing.sm

        Text {
            text: "content_paste"
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.lg
            color: Color.textMuted
        }

        TextInput {
            id: input
            Layout.fillWidth: true
            color: Color.text
            font.pixelSize: Size.fontSize.lg
            selectionColor: Color.primary
            selectedTextColor: Color.primaryText
            clip: true

            // 焦点要自己抢：容器内容装在 RailContainer 的 Loader 里，而 Loader
            // 自己就是一个 focus scope，声明 focus 传不到 keyScope 上去
            // （详见 AppSearchCard 里那段）
            focus: true
            Component.onCompleted: Qt.callLater(input.forceActiveFocus)

            Connections {
                target: root.sharedState
                function onFocusTickChanged() { Qt.callLater(input.forceActiveFocus) }
            }

            // 单向绑定 + onTextEdited 回写：onTextChanged 会被 reset() 的程序性
            // 改写触发，容易绕成环
            text: root.sharedState ? root.sharedState.query : ""
            onTextEdited: root.sharedState.setQuery(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "搜索剪贴板..."
                color: Color.textMuted
                font.pixelSize: Size.fontSize.lg
                visible: input.text.length === 0
            }

            Keys.onReturnPressed: (event) => {
                root.sharedState.paste(); event.accepted = true
            }
            Keys.onEnterPressed: (event) => {
                root.sharedState.paste(); event.accepted = true
            }
            Keys.onUpPressed: (event) => {
                root.sharedState.move(-1); event.accepted = true
            }
            Keys.onDownPressed: (event) => {
                root.sharedState.move(1); event.accepted = true
            }
            Keys.onLeftPressed: (event) => {
                root.sharedState.moveSide(-1); event.accepted = true
            }
            Keys.onRightPressed: (event) => {
                root.sharedState.moveSide(1); event.accepted = true
            }
            // Delete 删选中那条。抢这个键不亏：←→ 已经给了导航，文本光标动不了，
            // 光标永远在末尾，Delete 在输入框里本来就没事干（能用的是 Backspace）
            //
            // **自动重复一律吞掉**：删除是不可逆的（cliphist 没有回收站），而键盘
            // 重复是 ~30 次/秒 —— 按住三秒就是九十来条真删除。2026-09-05 就这么
            // 丢过一整份历史。想连删就一下一下按
            Keys.onDeletePressed: (event) => {
                event.accepted = true
                if (event.isAutoRepeat)
                    return
                root.sharedState.removeSelected()
            }
        }

        Text {
            text: Clipboard.filtered.length + " 条"
            color: Color.textMuted
            font.pixelSize: Size.fontSize.xsm
            visible: Clipboard.filtered.length > 0
        }

        // 清空搜索词（有词才露）
        QslIconButton {
            buttonSize: 30
            iconSize: 17
            icon: "close"
            visible: input.text.length > 0
            // 清空走共享状态，不直接改 input.text：直接改会打断上面那条绑定
            onClicked: root.sharedState.setQuery("")
        }

        // 清空整个历史
        QslIconButton {
            buttonSize: 30
            iconSize: 17
            icon: "delete"
            onClicked: Clipboard.clear()
        }
    }
}
