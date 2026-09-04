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

    // 每页宽度（pages[page].width 覆盖全局 containerWidth）：
    // 页面饭量不同，时间窄、系统宽
    readonly property int pageWidth: (pages[page] && pages[page].width)
        ? pages[page].width : containerWidth
    // 垂直停靠："top"（默认，从 56 起向下排）/ "bottom"（贴底 16，N 用）
    property string valign: "top"

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
        + staggerStep * Math.max(0, headerComp ? containerCount : containerCount - 1)

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
    // 压在顶栏之上）。现在直接写坐标，语义一样，但改宽不再引起 buffer 重建
    // TODO: bottom 边的布局（Row 横排 + 水平居中，迁移 A/Z/X 时补）
    implicitWidth: root.edge === "bottom"
        ? (parent ? parent.width : 0)
        : 8 + root.pageWidth + 16
    width: implicitWidth
    height: parent ? parent.height : 0
    x: root.edge === "right" && parent ? parent.width - width : 0
    y: 0

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
        // edge/valign 一起交上去：贴边三组会被登记成框边水波的波源，水波按登记表
        // 自己决定什么时候放波（原先是发一条 opened 信号让框窗去 trigger，
        // 那条信号已经删掉——绑定能表达的事不需要信号）
        Panels.claim(root.shellNamespace, root.panelGroup, root.edge, root.valign)
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
            exitStaggerMs: root.containerCount * root.staggerStep
        }

        // 容器列：贴 rail 竖排；left 边 x=8，right 边 x=16（rail 在右）
        // 无页首件的页从 56 起向下排；valign="bottom" 的页贴底（bottomrail 上方 16）
        Column {
            id: containerCol
            x: root.edge === "right" ? 16 : 8
            y: root.valign === "bottom"
                ? 0
                : (root.headerComp
                    ? 56 + headerContainer.implicitHeight + Size.spacing.md
                    : 56)
            anchors.bottom: root.valign === "bottom" ? parent.bottom : undefined
            anchors.bottomMargin: 16
            spacing: Size.spacing.md

            // 上面的容器长高/变矮时，下面的容器要滑下去而不是瞬移。
            // 只挂 move：add/remove 由容器自己的派生/收回动画负责，
            // 再挂一套会和 progress 打架
            move: Transition {
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
                    gate: root.derivGate
                    present: root.open && root.pendingPage === ""
                        && root.replayingIndexes.indexOf(index) === -1
                    staggerMs: (root.headerComp ? index + 1 : index) * root.staggerStep
                    // 退场自下而上（见 RailContainer.exitStaggerMs）。表头排在最后，
                    // 所以这里不含表头那一格：最底下的容器 0 延迟、最上面的
                    // (count-1) 格。exitAllMs 里那个 max 算的正是这个上界
                    exitStaggerMs: (root.containerCount - 1 - index) * root.staggerStep

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
