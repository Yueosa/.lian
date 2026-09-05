// RailPage — 进入模式页面：一个锚点上一组 RailContainer 的编排
//
// 条带（left/right=全高竖条，bottom=全宽横条）。
// 开页铺满点空白关闭 + Esc；Tab/Shift+Tab 循环页面。
// 切页 = 旧容器全部收回（Exit）→ 换模型 → 新容器级联派生（stagger）：
//   pendingPage 期间所有容器 present=false，swapTimer 等 Exit 播完再换模型。
// 页面模型：pages = { id: { title, icon, containers: [Component...] } }
//
// plan 第 6 轮起不再自带窗口：原先每个实例是一个 Overlay 层的 PanelWindow，
// 自管 layer / keyboardFocus / mask。现在画在 FrameWindow 里，那三件事交给
// 框窗归并（一个 surface 只有一份），本文件通过 wantsOverlay / wantsKeyboard /
// hitBox 三个只读属性把诉求报上去。换来两件东西：
//   1. 键盘归属从「合成器裁决」变成 Panels 的显式焦点栈
//   2. 框窗改用 OnDemand + HyprlandFocusGrab 之后，点面板外面能关窗了
//      （grab 的 cleared 信号；面板自己的 mask 只盖住贴边条带，收不到框外点击）
// 注：这里以前写着「省掉 ~190ms 的 Exclusive 停顿」，那条结论是错的；后来改写
// 成「真凶是 QML 的 GC」，同样是错的。真凶是 TrayMenu 里一份菜单关着也不解除的
// dbusmenu 订阅 —— 焦点只是触发器，详见 FrameWindow 与 TrayMenu 里的说明

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    property string edge: "left"
    property string shellNamespace: "qsl-railpage"
    // 互斥组名（见 Panels）：同组同时只开一个。空串 = 不参与互斥
    property string panelGroup: ""
    property var pages: ({})
    property var order: []
    property string page: ""
    property bool open: false
    property int containerWidth: 480
    property int staggerStep: 60
    // 退场的错峰步长，默认跟进场一致。
    // 底边堆叠那类页面（A）把 staggerStep 当「下一拍」用，步长是几百毫秒；
    // 退场不需要复述三拍，照那个步长走会在中间空等一大截（实测 A：搜索框
    // 200ms 收完，列表要等到 560ms 才动）。所以退场单独给一个紧凑的
    property int exitStaggerStep: staggerStep
    // 容器"内容长高/变矮"用的曲线（见 RailContainer.elasticType）。
    // 默认带过冲；高度会被高频重定目标的页（A 边打字边换高度）要换掉
    property int elasticType: Anim.SpatialFast

    // 每页宽度（pages[page].width 覆盖全局 containerWidth）：
    // 页面饭量不同，时间窄、系统宽
    readonly property int pageWidth: (pages[page] && pages[page].width)
        ? pages[page].width : containerWidth
    // 垂直停靠："top"（默认，从 56 起向下排）/ "bottom"（贴底 16，N 用）
    property string valign: "top"
    // 贴底锚定：容器列锚在屏幕下沿、向上摞。两条路进来——右边栏里贴底的
    // （N），和长在底 rail 上的（A / Z）。它们的高度变化由**顶边**吸收，
    // 底下那格因此永远不动，是这一族面板的定位口径
    readonly property bool bottomAnchored: root.valign === "bottom"
        || root.edge === "bottom"

    // 页首固定件（pages[page].header）：钉在页面顶部 y=56。
    // 不是容器、不参与派生、不随内容高度变化——tab 条就该是死的
    readonly property var headerComp: (pages[page] && pages[page].header)
        ? pages[page].header : null

    // 派生动画的起跑闸。
    //
    // 要躲的是**开窗那一拍的同步重活**：容器的 bodyLoader 是同步创建的
    // （它的 active 挂 present，开窗即真，并不等这道闸），页面越大堵得越久；
    // 而 Qt 的统一动画时钟在主线程阻塞期间照走——就在这一帧起派生动画，动画的
    // 起点会被记成阻塞之前那个 tick，第一帧画出来时它已经自己跑掉一截（岛那边
    // 实测首帧宽度从 202 直接跳到 482，同一个病）。
    //
    // 这里原先是一条 **230ms 固定延时**，属性名叫 focusSettleMs——名字来自
    // 「申请 Exclusive 要停 180ms」那个已被推翻的结论（真凶是 TrayMenu 那份关着
    // 也不解除的 dbusmenu 订阅，见 FrameWindow 里那段）。固定延时的毛病是不管
    // 有没有重活都白等，用户报的「CVN 首次弹出手感差」就是它。
    //
    // 换成帧闸：**帧在主线程阻塞期间不会 tick**，所以「数够两帧」天然等价于
    // 「重活干完，而且落到了干净的帧边界上」——不用猜时长，没重活时也不白等。
    // 冷开的等待因此从 230ms 降到两帧（约 34ms）。
    //
    // 两帧而不是一帧：第一帧可能正是阻塞结束的那一帧（时钟已经偏了），要再等
    // 一个完整帧间隔才能确认时钟重新对齐。与 IslandShell.hubShaped 同一套。
    //
    // 顺带删掉了 skipFocusSettle（曾用来让「面板互切」跳过那 230ms）：帧闸下冷开
    // 和互切都只等两帧，这个分支没有存在意义了。
    readonly property bool derivGate: gateOpen
    property bool gateOpen: false
    property int _gateFrames: 0

    // 帧闸的典型耗时。给 enterAllMs 排「派生动画期间别做重活」用——它只需要一个
    // 量级正确的常数，真实闸门长度由帧决定
    readonly property int gateLatencyMs: 34

    FrameAnimation {
        running: root.open && !root.gateOpen
        onTriggered: {
            root._gateFrames += 1
            if (root._gateFrames >= 2)
                root.gateOpen = true
        }
    }

    // 用 Connections 而不是 onOpenChanged：子类（Rightbar/NotifCenter）
    // 自己声明了 onOpenChanged，基类再写一个会撞
    Connections {
        target: root
        function onOpenChanged() {
            root._gateFrames = 0
            root.gateOpen = false
        }
    }

    // 当前页容器数。切页期间 page 还是旧页，所以这就是「正在退场的那一批」
    readonly property int containerCount: (pages[page] && pages[page].containers)
        ? pages[page].containers.length : 0

    // 旧页全部收回完毕的真实时长 = 最后一个容器的错峰延迟 + Exit 时长 + 余量。
    // 绝不能写成常量：容器按 staggerStep 依次退场，5 容器的系统页实际要
    // (5-1)*60+200=440ms，而常量 260ms 会在还剩两个容器退场中途就换模型，
    // Repeater 把未退完的容器重新赋值 → 容器瞬移 + 卡顿。
    // 页数不同→容器数不同→等待时长必须跟着算，这就是「不同 tab 容器数量
    // 不一样、动画播太快就出问题」的根因
    readonly property int exitAllMs: Size.anim.durFx + 60
        + exitStaggerStep * Math.max(0, headerComp ? containerCount : containerCount - 1)

    // 同理的入场侧：最后一个容器派生完毕的时刻（Anim.Spatial = durNormal）。
    // 给「派生动画期间别做重活」用。要含起跑闸那一段——派生是等闸开才起的，
    // 不算进来的话服务启停会提前落到动画里
    readonly property int enterAllMs: Size.anim.durNormal + 60 + gateLatencyMs
        + staggerStep * Math.max(0, headerComp ? containerCount : containerCount - 1)

    // ---- 详情档时序：供数页 = page 的「下降沿滞后」副本 ----
    //
    // 上升沿立刻。服务启动是同步大活（Sysmon.setDetailActive(true) 一次 fork
    // 三个进程），但派生动画要等起跑闸才起，所以开窗后那一拍本来就是动画前空档，
    // 启动开销落在里面不花钱。**帧闸把这一条守得比原来的 Timer 更牢**：主线程
    // 忙着 fork 时帧压根不 tick，闸门自然往后推，动画不会被插帧；而 fork 很快
    // 时也不会像固定延时那样白等。
    // 上升沿曾经也做过滞后，结果是系统页进程列表肉眼可见地慢（进程 CPU%
    // 还要两次采样，一叠加更明显）——那是白付的代价，已撤。
    //
    // 下降沿必须滞后到收回播完，否则关窗瞬间数据就空了，列表先空、面板后收。
    readonly property string detailTarget: (open && pendingPage === "") ? page : ""
    property string detailPage: ""

    onDetailTargetChanged: {
        if (detailTarget === "") {
            detailDown.restart()
        } else {
            detailDown.stop()
            detailPage = detailTarget
        }
    }

    Timer {
        id: detailDown
        interval: root.exitAllMs
        onTriggered: root.detailPage = ""
    }

    // 非空 = 切页中（旧容器收回中）
    property string pendingPage: ""
    // 非空 = 这些序号的容器正在回放（子 tab 切换的收回→派生）
    property var replayingIndexes: []

    // ---- 窗内几何：贴边条带 ----
    // 合并前靠窗口 anchors 贴边（且 exclusionMode: Ignore，所以从 y=0 起算，
    // 压在顶栏之上）。现在直接写坐标，语义一样，但改宽不再引起 buffer 重建。
    //
    // left/right = 全高竖条；bottom = 全宽横条，高度由页面给（stripHeight）。
    // 为什么不让它跟内容高度走：这条条带就是 inputMask，而 mask 每帧变就是每帧
    // 一次合成器往返——C/V/N 三条都是「开=整条、关=0」两态。底边的内容高度是
    // 弹性的（A 的列表随候选数收缩），所以取一个固定上界，别跟着抖。
    // 条带之外的点击不用它管：框窗的 HyprlandFocusGrab 一 cleared 就全关
    property int stripHeight: 0

    implicitWidth: root.edge === "bottom"
        ? (parent ? parent.width : 0)
        : 8 + root.pageWidth + 16
    width: implicitWidth
    height: root.edge === "bottom" && root.stripHeight > 0
        ? root.stripHeight
        : (parent ? parent.height : 0)
    x: root.edge === "right" && parent ? parent.width - width : 0
    y: root.edge === "bottom" && parent ? parent.height - height : 0

    // ---- 底边的水平位置 ----
    // 底 rail 容得下不止一个面板，各占一段：A 在中段、Z/X 在左段（它们和 A
    // 不重叠，所以不互斥；Z 压着 C 那一列的下半截，跟 C 一组）。
    // 左段和左边那条 rail 同一个 x=8 口径，卡片左沿与 C 的卡片对齐
    property string halign: "center"   // "center" | "left"
    readonly property int colX: root.edge === "bottom"
        ? (root.halign === "left"
            ? 8 : Math.round((root.width - root.pageWidth) / 2))
        : (root.edge === "right" ? 16 : 8)

    // 报给水波的沿边锚点（底边给屏幕 x，其余边不给、由水波按定比内缩取）。
    // 取卡片中线：波从面板正下方生出来，两个波前各往一头跑
    readonly property real edgeAnchor: root.edge === "bottom"
        ? root.colX + root.pageWidth / 2 : -1

    // 底边堆叠：下面那格的槽位比它的内容早开多久 = 「脱离」那一拍的长度。
    // 三拍读起来是：上面的容器长出来 → 被下面那格顶起来（这一拍） → 下面的
    // 内容从 rail 里长进让出来的缝
    property int slotLeadMs: Size.anim.durFast

    // ---- 报给 FrameWindow 的三项窗口级诉求 ----
    // 曾经这里写着「申请 Exclusive 要停 ~190ms，所以两头都要把它挪出动画窗口」，
    // 那条结论是错的（隔离复现见 FrameWindow 里的说明；真凶是 GC）。
    // 但这两个属性的**写法**照旧是对的，只是理由换了：
    //   开窗——open 一置真就要键盘，Esc 得马上能用
    //   关窗——延到收回播完（detailDown 跑完）才松手，否则退场期间键盘已经还给
    //          应用，这时候按 Esc 会打到应用身上
    readonly property bool wantsKeyboard: open || detailDown.running
    // 合并前恒为 Overlay 层。现在跟着开关：关掉后框窗要落回 Top，
    // 否则 bar/rail 会一直骑在全屏窗之上
    readonly property bool wantsOverlay: open || detailDown.running
    readonly property Item hitBox: inputMask

    function toggle(p) {
        open ? closeWindow() : openPage(p)
    }


    function openPage(p) {
        if (p !== undefined && p !== null && String(p).length > 0)
            page = String(p)
        // 不再 Island.captureFocus()：框窗用 HyprlandFocusGrab，不抢应用焦点
        // 登记互斥 + 压焦点栈：同组（= 同一块屏幕区域）只留一个，见 Panels。
        // edge/valign/edgeAnchor 一起交上去：贴边的面板会占一格框边水波的波源
        // 槽位，水波按槽位自己决定什么时候放波（原先是发一条 opened 信号让框窗
        // 去 trigger，那条信号已经删掉——绑定能表达的事不需要信号）
        Panels.claim(root.shellNamespace, root.panelGroup, root.edge, root.valign,
                     root.edgeAnchor)
        open = true
        // 每次开窗都主动夺焦：内容里的输入框（密码框/标签框）一旦
        // forceActiveFocus 过，光靠 focus: root.open 绑定夺不回来
        Qt.callLater(() => keyScope.forceActiveFocus())
    }

    // 子类别重写这个：里面三行是记账（退栈、还焦点），抄一遍就会抄漏——
    // N 就抄漏过 Panels.release，僵尸条目留在 Panels 里，合并框窗之后键盘
    // 归属会卡死在一个已经关掉的面板上。要加关闭侧清理请挂 onOpenChanged
    function closeWindow() {
        if (!open)
            return
        open = false
        Panels.release(root.shellNamespace)
        // 这里曾经要判断「栈空了才把焦点还给应用」，还要 spawn 一个 hyprctl。
        // 框窗改 HyprlandFocusGrab 之后两件都没了：grab 的存活是
        // wantsKeyboard 的绑定（横跨整段退场动画），焦点也从没被抢走过
    }

    Connections {
        target: Panels

        // 被别的面板挤掉：自己收场，走正常关窗路径（动画/焦点归还都照旧）
        function onEvicted(id) {
            if (id === root.shellNamespace)
                root.closeWindow()
        }

        // 栈顶换人（前一个面板关掉了，键盘该落到我头上）：要主动夺焦。
        // 光靠上面 focus 那条绑定夺不回来——内容里的输入框（密码框/标签框）
        // 一旦 forceActiveFocus 过就赖着不放，同 openPage 的注释
        function onKeyboardOwnerChanged() {
            if (root.open && Panels.keyboardOwner === root.shellNamespace)
                Qt.callLater(() => keyScope.forceActiveFocus())
        }
    }

    // Esc 默认关窗；有子页的实例可覆盖（N 在应用详情页先退回列表）
    function escPressed() {
        closeWindow()
    }

    function cycle(step) {
        if (order.length === 0)
            return
        const i = Math.max(0, order.indexOf(page))
        switchTo(order[(i + step + order.length) % order.length])
    }

    // 子 tab 切换用：让第 index 个容器播"收回→派生"而不动整页。
    // 容器收回即卸载，重新派生时是新实例，自然读到最新共享状态
    function replayContainer(index) {
        replayingIndexes = replayingIndexes.concat([index])
        replayTimer.restart()
    }

    Timer {
        id: replayTimer
        interval: root.exitAllMs
        onTriggered: root.replayingIndexes = []
    }

    function switchTo(p) {
        if (!pages[p] || p === page)
            return
        if (!open) {
            openPage(p)
            return
        }
        pendingPage = p
        swapTimer.restart()
    }

    Timer {
        id: swapTimer
        interval: root.exitAllMs   // 等旧页「全部」容器 Exit 播完，不是等一个
        onTriggered: {
            root.page = root.pendingPage
            root.pendingPage = ""
        }
    }

    // 开页整条可点空白关；关页清零不挡桌面。框窗把它并进自己的 mask
    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    // 页面框架按序号取容器（子 tab 交换时用）
    function containerAt(i) {
        return containerRepeater.itemAt(i)
    }

    // 按键作用域：必须包住全部内容（页首件 + 容器列）。
    // 内容放在 FocusScope 外面（兄弟节点）时，内容里任何一个 TextInput
    // 拿到 activeFocus 就把焦点带出了本子树，Keys.onPressed 从此不再触发
    // ——Tab/Esc 同时死、鼠标照常，且重开也回不来（V 面板焦点饥饿的真根因）。
    // 不写 enabled: root.open：禁用项不能持有 activeFocus（岛同注释）
    //
    // 合并框窗之后多了一个条件：整个窗只有一个 activeFocusItem，而跨区域可以
    // 同时开着 C 和 V。谁响应 Esc/Tab 由 Panels 的焦点栈裁决（栈顶），不再是
    // 「两个窗都申请 Exclusive、看合成器给谁」
    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: root.open && Panels.keyboardOwner === root.shellNamespace
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.escPressed()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backtab) {
                root.cycle(-1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Tab) {
                root.cycle((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                event.accepted = true
            }
        }

        // 点空白关闭：声明在内容之前，内容盖在它上面照常收点击
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }

        // 页首固定件（tab 条）：正经 RailContainer（有壳有派生动画），
        // 但位置钉死在 y=56——不参与容器列布局，下面怎么变它都不动
        RailContainer {
            id: headerContainer
            x: 8
            y: 56
            edge: root.edge
            gate: root.derivGate
            sourceComponent: root.headerComp
            naturalWidth: root.pageWidth
            present: root.open && root.pendingPage === ""
                && root.headerComp !== null
            visible: root.headerComp !== null
            // 进场领头（staggerMs 默认 0），退场压尾——整页读起来就是原路收回。
            // 表头收回不会推动容器列：列的 y 取的是表头**冻结后的** implicitHeight
            exitStaggerMs: root.containerCount * root.exitStaggerStep
        }

        // 容器列：贴 rail 竖排；left 边 x=8，right 边 x=16（rail 在右）
        // 无页首件的页从 56 起向下排；valign="bottom" 的页贴底（bottomrail 上方 16）
        // 底边的页：水平位置看 halign（居中 / 左段）、贴底，容器沿**行程轴**
        // 向上摞（见 RailContainer.slotGrows）
        Column {
            id: containerCol
            x: root.colX
            y: root.bottomAnchored
                ? 0
                : (root.headerComp
                    ? 56 + headerContainer.implicitHeight + Size.spacing.md
                    : 56)
            anchors.bottom: root.bottomAnchored ? parent.bottom : undefined
            // 底边的页贴**在** rail 上（8 = rail 厚度，同 left 边的 x: 8），
            // 卡片底边和 rail 顶边严丝合缝，耳朵才有接缝可填。
            // 16 是 valign="bottom" 的口径：N 贴的是右 rail，16 是给底 rail 让的空
            anchors.bottomMargin: root.edge === "bottom" ? 8 : 16
            // 底边不用 spacing：缝由容器的 slotGapAbove 带着一起长。
            // spacing 是阶跃的——槽位从 0 长到 1px 那一帧，整条缝会插进来，
            // 上面的容器凭空跳一截（这类瞬移正是 exitStaggerMs 那段的教训）
            spacing: root.edge === "bottom" ? 0 : Size.spacing.md

            // 退场期间列高冻住。
            //
            // 贴底锚定的列，高度一缩顶边就往下走 —— 开着的时候这正是要的效果
            // （见下面 move 那段：A 搜索时列表变矮，搜索框纹丝不动）。但退场时
            // 它是灾难：容器退完就卸载，那一格的高度在一帧内归零，列高跟着塌
            // 一大截，顶边猛地下移，还在退场路上的上面那格被一起拖下去。
            // N 的症状就是这个——列表先退完（退场自下而上），标题卡退到一半
            // 突然瞬移到屏幕底部。
            // 关窗那一刻把高度记下来，整段退场按它算，谁也不拖谁
            property real exitH: 0
            height: root.bottomAnchored && !root.open
                ? containerCol.exitH : containerCol.implicitHeight

            Connections {
                target: root
                // 不直接在 root 上写 onOpenChanged：那个信号处理器留给子类，
                // 基类再声明一份会被子类的声明顶掉（N 就抄漏过一次记账）
                function onOpenChanged() {
                    if (!root.open)
                        containerCol.exitH = containerCol.implicitHeight
                }
            }

            // 上面的容器长高/变矮时，下面的容器要滑下去而不是瞬移。
            // 只挂 move：add/remove 由容器自己的派生/收回动画负责，
            // 再挂一套会和 progress 打架。
            //
            // **贴底锚定的列（A / valign=bottom）必须不挂**：列的顶边已经在吸收
            // 高度变化了（高度缩 Δ，顶边就下移 Δ），列内 y 再动一次就是动了两次，
            // 而且两次的时钟不一样——列高跟着卡片的高度动画走，列内 y 走这条
            // move 过渡，慢一截。实测 A 搜索时列表 6 行缩到 1 行：搜索框的屏幕 y
            // 从 1012 冲到 1145（屏幕只有 1080，整条掉出屏幕），再花 ~500ms 爬回来
            // ——用户读成「搜索框重新加载了」。
            // 不挂之后 srchScrY = (1072 - listH - 60) + listH ≡ 1012，纹丝不动，
            // 而列表本身的高度动画还在（卡片自己的 Behavior），该动的照样动
            move: root.bottomAnchored ? null : columnMove
            Transition {
                id: columnMove
                Anim { properties: "y"; type: Anim.SpatialFast }
            }

            Repeater {
                id: containerRepeater
                model: (root.pages[root.page] && root.pages[root.page].containers)
                    ? root.pages[root.page].containers
                    : []

                RailContainer {
                    id: containerItem
                    required property var modelData
                    required property int index

                    edge: root.edge
                    sourceComponent: modelData
                    // 占位规则：已加载且自报空（hasContent=false）才不占位；
                    // 未加载/已卸载都保留占位——0 高挡幻影，退场期防瞬移
                    readonly property bool occupied: containerItem.bodyItem
                        ? containerItem.bodyItem.hasContent !== false
                        : true
                    // 不占位要先播收回，播完才真的让出槽位。
                    // 直接切 visible 是瞬间生效的——关掉 wifi/蓝牙时列表卡就那样
                    // 硬生生消失，开回来又硬生生出现，中间没有过渡
                    shown: containerItem.occupied
                    visible: containerItem.wantOpen || containerItem.progress > 0.001
                    naturalWidth: root.pageWidth
                    elasticType: root.elasticType
                    // 底边贴左段的页：卡片左沿压在左 rail 内沿上，接缝要改到
                    // 左上角（见 RailContainer.weldLeft）
                    weldLeft: root.edge === "bottom" && root.halign === "left"
                    gate: root.derivGate
                    present: root.open && root.pendingPage === ""
                        && root.replayingIndexes.indexOf(index) === -1
                    staggerMs: (root.headerComp ? index + 1 : index) * root.staggerStep

                    // ---- 底边堆叠 ----
                    // 最底那格贴着 rail；它上面每一格的槽位都由**下面那格**顶开。
                    slotGrows: root.edge === "bottom" && index > 0
                    slotGapAbove: (root.edge === "bottom" && index > 0)
                        ? Size.spacing.md : 0
                    slotStaggerMs: Math.max(0, containerItem.staggerMs - root.slotLeadMs)
                    // 抬离 rail 多远（列底就是 rail 那一侧）。故意用自己的几何算，
                    // 不去翻 containerRepeater.itemAt(index+1) 拿兄弟的 slotProgress：
                    // Repeater 里那种引用既不响应也不保证已创建。24px 是过渡尺度——
                    // 抬起这么多就算完全脱离，耳朵淡完、贴 rail 那两个角圆完
                    readonly property real liftPx: containerCol.height
                        - (containerItem.y + containerItem.height)
                    detached: root.edge === "bottom"
                        ? Math.min(1, Math.max(0, containerItem.liftPx / 24))
                        : 0
                    // 退场自下而上（见 RailContainer.exitStaggerMs）。表头排在最后，
                    // 所以这里不含表头那一格：最底下的容器 0 延迟、最上面的
                    // (count-1) 格。exitAllMs 里那个 max 算的正是这个上界
                    exitStaggerMs: (root.containerCount - 1 - index) * root.exitStaggerStep

                    // 页内内容可向页面请求关闭（对齐旧 requestClose 惯例）；
                    // bodyItem 用 RailContainer 自带的 alias——在本文件重复声明并
                    // 引用内部 id bodyLoader 是拿不到的，还会覆盖掉 alias（事故过）
                    Connections {
                        target: containerItem.bodyItem
                        ignoreUnknownSignals: true
                        function onRequestClose() { root.closeWindow() }
                    }
                }
            }
        }
    }
}
