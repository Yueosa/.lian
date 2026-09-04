// RailPage — 进入模式页面窗口：一个锚点上一组 RailContainer 的编排
//
// 窗口：条带（left/right=全高竖条，bottom=全宽横条），Overlay 层。
// 开页铺满点空白关闭 + Esc；Tab/Shift+Tab 循环页面。
// 切页 = 旧容器全部收回（Exit）→ 换模型 → 新容器级联派生（stagger）：
//   pendingPage 期间所有容器 present=false，swapTimer 等 Exit 播完再换模型。
// 页面模型：pages = { id: { title, icon, containers: [Component...] } }

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Components
import qs.data.state

PanelWindow {
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

    // 焦点结算延迟。申请 Exclusive 会让主线程停 ~180ms（实测），而这笔钱
    // 是延迟到达的——不能拿「焦点已到位」当信号，它在代价付清之前就已经为真。
    // 所以用确定性延时：开窗立刻申请焦点，等这一拍过去再起派生动画，
    // 于是掉帧变成了「面板晚 230ms 才开始出现」。手感不对就调这个值。
    // 切页不重新申请焦点，所以不付这笔钱——这也正是「按 Tab 循环从来不卡」的原因
    property int focusSettleMs: 230

    // 容器派生的开闸信号
    readonly property bool derivGate: gateOpen
    property bool gateOpen: false

    Timer {
        id: gateTimer
        interval: root.focusSettleMs
        repeat: false
        onTriggered: root.gateOpen = true
    }

    // 用 Connections 而不是 onOpenChanged：子类（Rightbar/NotifCenter）
    // 自己声明了 onOpenChanged，基类再写一个会撞
    Connections {
        target: root
        function onOpenChanged() {
            if (root.open) {
                root.gateOpen = false
                gateTimer.restart()
            } else {
                gateTimer.stop()
                root.gateOpen = false
            }
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
    // 给「派生动画期间别做重活」用。要含 focusSettleMs——派生是等焦点结算完
    // 才起的，不算进来的话服务启停会提前 focusSettleMs 落到动画里
    readonly property int enterAllMs: Size.anim.durNormal + 60 + focusSettleMs
        + staggerStep * Math.max(0, headerComp ? containerCount : containerCount - 1)

    // ---- 详情档时序：供数页 = page 的「下降沿滞后」副本 ----
    //
    // 上升沿立刻。服务启动是同步大活（Sysmon.setDetailActive(true) 一次 fork
    // 三个进程），但派生动画要等 focusSettleMs 才起，所以开窗后那一拍本来就是
    // 动画前空档，启动开销落在里面不花钱。而且门闸是 Timer：主线程忙着 fork
    // 时它压根不会触发，动画自然排在后面，不会被插帧。
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

    color: "transparent"
    visible: true

    // TODO: bottom 边的布局（Row 横排 + 水平居中，迁移 A/Z/X 时补）
    anchors {
        left: root.edge === "left" || root.edge === "bottom"
        right: root.edge === "right" || root.edge === "bottom"
        top: root.edge !== "bottom"
        bottom: true
    }
    exclusiveZone: 0

    WlrLayershell.namespace: root.shellNamespace
    WlrLayershell.layer: WlrLayer.Overlay

    // 键盘焦点的代价：实测申请 Exclusive 会让 qs 主线程停 ~190ms
    // （QSG_RENDER_LOOP=basic 下渲染在主线程同步跑，这是事件循环真的卡住）。
    // A/B 实证：把 keyboardFocus 恒定 None，开关的 ≥50ms 停顿从 4 次 734ms 归零。
    // 所以两头都把这 190ms 挪出动画窗口，且方向相反：
    //   开窗——立刻申请（Esc 要能马上用），但派生动画等焦点到位再起，
    //          于是 190ms 变成「开面板慢一点」而不是「动画掉帧」
    //   关窗——立刻播收回，焦点等收回播完再还（detailDown 跑完），
    //          否则这 190ms 正好砸在退场动画上
    WlrLayershell.keyboardFocus: (open || detailDown.running)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // 窗口宽度：rail(8) + 容器 + 外边距
    implicitWidth: root.edge === "bottom" ? 0 : 8 + root.pageWidth + 16

    function toggle(p) {
        open ? closeWindow() : openPage(p)
    }


    function openPage(p) {
        if (p !== undefined && p !== null && String(p).length > 0)
            page = String(p)
        if (!open)
            Island.captureFocus()
        // 登记互斥：同组（= 同一块屏幕区域）只留一个，见 Panels
        Panels.claim(root.shellNamespace, root.panelGroup)
        open = true
        // 每次开窗都主动夺焦：内容里的输入框（密码框/标签框）一旦
        // forceActiveFocus 过，光靠 focus: root.open 绑定夺不回来
        Qt.callLater(() => keyScope.forceActiveFocus())
    }

    function closeWindow() {
        if (!open)
            return
        open = false
        Panels.release(root.shellNamespace)
        Island.restoreFocus()
    }

    // 被别的面板挤掉：自己收场，走正常关窗路径（动画/焦点归还都照旧）
    Connections {
        target: Panels
        function onEvicted(id) {
            if (id === root.shellNamespace)
                root.closeWindow()
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

    // 开页全屏可点空白关；关页清零不挡桌面
    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    // 页面框架按序号取容器（子 tab 交换时用）
    function containerAt(i) {
        return containerRepeater.itemAt(i)
    }

    // 按键作用域：必须包住全部内容（页首件 + 容器列）。
    // 内容放在 FocusScope 外面（兄弟节点）时，内容里任何一个 TextInput
    // 拿到 activeFocus 就把焦点带出了本子树，Keys.onPressed 从此不再触发
    // ——Tab/Esc 同时死、鼠标照常，且重开也回不来（V 面板焦点饥饿的真根因）。
    // 不写 enabled: root.open：禁用项不能持有 activeFocus（岛同注释）
    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: root.open
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
