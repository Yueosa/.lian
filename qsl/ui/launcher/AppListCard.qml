// AppListCard — A 的第一个容器：应用列表（三拍里第一个长出来的那张）
// 容器卡：背景/圆角/耳朵由宿主 RailContainer 提供，本卡只装内容
//
// 高度随候选数弹性收缩，上界 sharedState.maxRows 行；一个候选都没有时自报空，
// 由容器占位协议收回（RailContainer.shown），于是打错字时整页只剩一个搜索框。
// 选择态放在 sharedState 里而不是 ListView 里：按键落在**另一张卡**的输入框上，
// 两张卡之间只能经共享状态说话（对齐 N 的 notifState 惯例）。
//
// 动画照搬旧 AppPage：高亮移动 / 列表增删过渡 / 选中缩放 /
// Enter 时选中项留下放大、其余右滑淡出

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    anchors.fill: parent

    // 指向 Launcher.appState
    property QtObject sharedState

    readonly property int pad: Size.spacing.sm
    readonly property bool hasContent: root.sharedState
        ? root.sharedState.count > 0 : false

    // ---- 整块居中 ----
    // 每行各自居中试过：名字长短差得远（「QQ」对「The Honkers Railway
    // Launcher」），图标的 x 就跟着参差，一列扫下来很吵。改成所有行共用同一个
    // 偏移：块内图标对齐成一列、名字左对齐，块**整体**在卡里居中——空白摊到
    // 两侧，同时保留列表该有的竖直基准线。
    //
    // 块宽取**全部候选**里最长的那个名字，不是可见几行的：按可见行算，滚动时
    // 块宽会跟着变，整列文字左右横跳
    readonly property real rowInset: 12
    readonly property real availNameW: appList.width - 2 * root.rowInset
        - (root.sharedState ? root.sharedState.iconSize : 36) - Size.spacing.lg
    readonly property real maxNameW: {
        // revision 强制依赖：条数没变但内容换了（"a" 换成 "b" 都是 3 个结果）
        // 也要重量，否则块宽会卡在上一次的最长名字上
        void Apps.revision
        let w = 0
        for (let i = 0; i < Apps.rows.count; i++)
            w = Math.max(w, nameMetrics.advanceWidth(String(Apps.rows.get(i).app.name || "")))
        // 留一点余量：命中段是粗体，比测量用的常规字重宽一点，
        // 不留就会把最长那个名字的尾字 elide 掉
        return Math.min(w + 8, root.availNameW)
    }
    readonly property real blockW: (root.sharedState ? root.sharedState.iconSize : 36)
        + Size.spacing.lg + Math.max(0, root.maxNameW)

    FontMetrics {
        id: nameMetrics
        font.pixelSize: Size.fontSize.xl
    }

    implicitHeight: root.sharedState
        ? root.sharedState.visibleRows * root.sharedState.itemHeight + 2 * root.pad
        : 0

    // 吃掉点击，避免穿透到 RailPage 那层「点空白关闭」
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ListView {
        id: appList
        anchors.fill: parent
        // 四边同一个内边距。原来只留上下、左右为 0，高亮条于是直接顶到卡片两侧，
        // 而顶部还空着 8px —— 「上下有、左右没有」这种不对称让那 8px 读成卡片
        // 上方多出来的一块白（第一行总是选中态的深色，衬得格外明显）。
        // 四边一致之后高亮是一颗嵌在卡里的胶囊，白边成了均匀的一圈
        anchors.margins: root.pad
        clip: true
        // 增量模型（见 data/launcher/Apps.qml）：搜索时留下来的行滑动、
        // 走掉的行淡出，下面那三条过渡才有东西可播
        model: Apps.rows
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds

        // 高亮跟着选择走，**单向**：选择的真身只在 sharedState（键盘落在搜索框
        // 那张卡上），视图只是显示，永远不回写。
        //
        // 一开始是双向的（视图改了就回写共享状态），为的是鼠标滚动时高亮跟着走。
        // 两个 bug 都出在这条回写上：
        //   · 开窗时高亮落在列表中间某一行 —— 应用目录异步到货，模型一换
        //     StrictlyEnforceRange 自己挪 currentIndex，被回写当成「用户选了别的」，
        //     把 reset() 刚设的 index=0 顶掉
        //   · 一直按 ↓ 只到倒数第二个 —— 从倒数第二跳到最后那一下视图要滚动，
        //     滚动中途 StrictlyEnforceRange 又把 currentIndex 拨回去，绑定和视图
        //     互相打架，停在倒数第二。而单次按键能从最后一个绕回第一个（那一下
        //     index 变了，绑定重算，赢了这一回）——所以症状是「按住不行、单按行」
        //
        // 改 ApplyRange 之后视图不再自己动 currentIndex（只有 StrictlyEnforceRange
        // 会），回写也就不需要了。代价是滚轮拨列表不再改选中项——启动器本来就该
        // 这样：滚动是看，选中是键盘的事（rofi 同款）
        currentIndex: root.sharedState ? root.sharedState.index : 0

        // 高亮的活动范围：**上下各留一行**做上下文。
        //
        // preferredHighlight* 夹的是高亮整块（上沿 ≥ begin、下沿 ≤ end），不是它的
        // 上沿。所以 end = 高度 - 一行 时，按住 ↓ 滚动中的高亮停在第 5 行、下面
        // 留着第 6 行 —— 这个用户认可。begin 原来是 0，于是按住 ↑ 时高亮顶到第
        // 1 行、上面什么都不剩，两头不对称。给 begin 也留一行，↑ 停在第 2 行。
        //
        // 列表真正的头尾另说：那时视图滚不动了，ApplyRange 允许高亮走出这个范围，
        // 所以第 1 项和最后一项照样选得到（这正是不用 StrictlyEnforceRange 的好处）
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: root.sharedState ? root.sharedState.itemHeight : 56
        preferredHighlightEnd: height - (root.sharedState ? root.sharedState.itemHeight : 56)
        highlightMoveDuration: Size.anim.durFast
        highlight: Rectangle {
            color: Color.primary
            radius: Size.rounding.md
        }

        // **只留 displaced，不要 add / remove**：那两条动的是透明度，而搜索时每敲
        // 一个字模型就抖一次，动画播不完就被打断、透明度冻在中途（活着的行卡在
        // 半透明叠着别的东西）。完整证据和推理见 ClipCard.qml 同一处 —— Z 的剪贴板
        // 列表先踩的坑，这里是同一套机制
        displaced: Transition {
            // 被顶开的行：减速不过冲。带过冲的 spatial 在这儿是灾难——一次同步会
            // 连着顶开好几格，每格一次动画，过冲叠起来就是整列在抖
            Anim { property: "y"; type: Anim.EnterFast }
        }

        delegate: Item {
            id: appRow

            // app 是模型的角色名（Apps.rows 的每行存一个应用条目）
            required property var app
            required property int index

            width: ListView.view ? ListView.view.width : 0
            height: root.sharedState ? root.sharedState.itemHeight : 56

            readonly property QtObject s: root.sharedState
            readonly property bool current: ListView.isCurrentItem
            readonly property bool chosen: appRow.s.launching
                && appRow.index === appRow.s.launchIndex
            readonly property bool exiting: appRow.s.launching
                && appRow.index !== appRow.s.launchIndex
            readonly property real contentScale: appRow.chosen
                ? 1.12
                : (appRow.current && !appRow.s.launching ? 1.06 : 1.0)

            // 根节点的 opacity/y 归**视图**（上面那三条 Transition），别人不许碰。
            // 启动动画的淡出/右滑因此挂在内层 rowFade 上：Behavior 是属性写入
            // 拦截器，挂在根节点上会把 remove 过渡每一帧的写入也截下来重排，那条
            // 淡出于是永远走不到 0 —— 行停在半透明不走，而底下的行已经顶上来
            // 填了位置，看着就是「本该在别处的应用冒到这儿又自己消失」
            // （Z 的剪贴板列表踩的是同一个坑，见 ClipCard.qml）
            //
            // 淡到 0 的 item 进池子后，被复用来画滚进视野的新行时不走 add 过渡
            // （那只对模型插入生效），透明度就卡在 0。复用时手动收回来
            ListView.onReused: appRow.opacity = 1

            Item {
                id: rowFade

                anchors.fill: parent

                // 未选中项：向右滑出并淡出
                opacity: appRow.exiting ? 0 : 1
                x: appRow.exiting ? appRow.s.exitSlide : 0

                Behavior on opacity {
                    enabled: appRow.s.animEnabled
                    Anim { type: Anim.Exit }
                }
                Behavior on x {
                    enabled: appRow.s.animEnabled
                    Anim { type: Anim.Exit }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !appRow.s.launching
                    onClicked: {
                        appRow.s.index = appRow.index
                        appRow.s.run()
                    }
                }

                // 宽度和 x 都来自卡片（root.blockW），所以每行的图标在同一个 x 上；
                // 名字在块内左对齐。缩放原点在中心，不然选中项会往一侧挣出去
                RowLayout {
                    x: Math.round((appRow.width - root.blockW) / 2)
                    width: root.blockW
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Size.spacing.lg
                    scale: appRow.contentScale
                    transformOrigin: Item.Center

                    Behavior on scale {
                        enabled: appRow.s.animEnabled
                        Anim { type: Anim.EffectsFast }
                    }

                    // 图标三级回退：随包资产 svg → entry 自带图标 → 主题名 →
                    // application-x-executable → 字体字形。
                    // 图标查不到时 provider 交回的是占位图且 status 仍是 Ready，
                    // 所以只能靠 Image.Error 逐级降，不能靠 status 判断有无
                    Item {
                        id: iconRoot
                        Layout.preferredWidth: appRow.s.iconSize
                        Layout.preferredHeight: appRow.s.iconSize
                        Layout.alignment: Qt.AlignVCenter
                        readonly property bool forceFontFallback: !!appRow.app.forceGlyph

                        Rectangle {
                            anchors.fill: parent
                            radius: Size.rounding.xs
                            color: Color.withAlpha(Color.text, 0.08)
                            visible: iconRoot.forceFontFallback
                                || appImage.status !== Image.Ready
                        }

                        Image {
                            id: appImage
                            anchors.fill: parent
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            // 缓存开着：图标按应用固定不变，而搜索时同一批 delegate
                            // 会被反复换绑（reuseItems + 整体换），关缓存就是每次
                            // 重新解码一遍 svg/png。旧 A 页那会儿列表不动，关着不亏
                            cache: true
                            visible: status === Image.Ready && !iconRoot.forceFontFallback
                            property int failCount: 0

                            source: {
                                const m = appRow.app
                                if (m.assetAppId)
                                    return "file://" + Apps.logoDir + "/" + m.assetAppId + ".svg"
                                const ic = m.icon
                                if (iconRoot.forceFontFallback || !ic)
                                    return ""
                                if (ic.startsWith("/"))
                                    return "file://" + ic
                                if (ic.startsWith("file://") || ic.startsWith("image://"))
                                    return ic
                                return "image://icon/" + ic
                            }

                            onStatusChanged: {
                                if (status !== Image.Error)
                                    return
                                failCount++
                                if (failCount === 1 && appRow.app.fallbackIcon)
                                    source = "image://icon/" + appRow.app.fallbackIcon
                                else if (failCount === 2)
                                    source = "image://icon/application-x-executable"
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: iconRoot.forceFontFallback
                                || appImage.status !== Image.Ready
                            text: appRow.app.materialGlyph || "apps"
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.xl
                            color: appRow.current ? Color.primaryText : Color.text
                        }
                    }

                    // 应用名：命中那一段粗体加下划线（富文本，见 appState.styledName）。
                    // fillWidth 铺满块内剩余宽度（块宽已按最长名字算好），名字于是
                    // 左对齐；elide 只在块宽被卡片宽度截住时才用得上
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: appRow.s.styledName(appRow.app.name || "", appRow.s.query)
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        color: appRow.current ? Color.primaryText : Color.text
                        font.pixelSize: Size.fontSize.xl
                    }
                }
            }
        }
    }
}
