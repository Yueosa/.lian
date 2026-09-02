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
    // 页首固定件（pages[page].header）：钉在页面顶部 y=56。
    // 不是容器、不参与派生、不随内容高度变化——tab 条就该是死的
    readonly property var headerComp: (pages[page] && pages[page].header)
        ? pages[page].header : null

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
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        open = true
    }

    function closeWindow() {
        if (!open)
            return
        open = false
        Island.restoreFocus()
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
        interval: Size.anim.durFx + 60
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
        interval: Size.anim.durFx + 60   // 等旧容器 Exit 播完
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

    FocusScope {
        anchors.fill: parent
        enabled: root.open
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
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

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }
    }

    // 页面框架按序号取容器（子 tab 交换时用）
    function containerAt(i) {
        return containerRepeater.itemAt(i)
    }

    // 页首固定件（tab 条）：正经 RailContainer（有壳有派生动画），
    // 但位置钉死在 y=56——不参与容器列布局，下面怎么变它都不动
    RailContainer {
        id: headerContainer
        x: 8
        y: 56
        edge: root.edge
        sourceComponent: root.headerComp
        naturalWidth: root.pageWidth
        present: root.open && root.pendingPage === ""
            && root.headerComp !== null
        visible: root.headerComp !== null
    }

    // 容器列：贴 rail 竖排；有页首件的页从它下面开始排；
    // 普通页居中但钳制 y≥56，不许跟 leftbar 黏上（底部空优于顶部黏）
    Column {
        id: containerCol
        x: 8
        y: root.headerComp
            ? 56 + headerContainer.implicitHeight + Size.spacing.md
            : Math.max(56, Math.round((root.height - containerCol.implicitHeight) / 2))
        spacing: Size.spacing.md

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
                // 内容自报空（hasContent=false）就不占位（如「已完成」为空）
                visible: containerItem.bodyItem
                    ? containerItem.bodyItem.hasContent !== false
                    : false
                naturalWidth: root.pageWidth
                present: root.open && root.pendingPage === ""
                    && root.replayingIndexes.indexOf(index) === -1
                staggerMs: index * root.staggerStep

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
