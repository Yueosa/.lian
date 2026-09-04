// FrameWindow — 合并框窗（plan 第 6 轮）
//
// 一个全屏透明窗装下整个「框」：顶栏两段 + 三边 rail + 灵动岛（往后还有 C/V/N）。
// 合并前这些是 9 个独立 Wayland surface，跨窗协调天然做不了——rail 水波就死在
// 这上面（面板那个窗没法往 rail 那个窗里画一个像素）。现在它们在同一棵场景图里，
// 共用一个坐标系、一次渲染出。
//
// 三件事分给了三个地方：
//   画    —— 本窗，exclusionMode: Ignore，覆盖整屏（含别人的独占区之下）
//   撑位  —— Exclusions.qml 的四个 1×1 隐形窗（一个 surface 只能声明一个 zone）
//   凹角  —— Ears.qml 的四颗 Bottom 层小窗（要压在应用窗口之下才不遮边框线）
//
// ============================================================
// 窗口级职责的聚合
//     一个 surface 只有一个 layer、一个 keyboardFocus、一个 mask。合并之后
//     这三样不再属于各个面板，而是要把所有租户的诉求并起来——这正是合并的
//     意义：以前岛要 Overlay 就自己升，现在是「有任何租户要 Overlay 就升」。
//     租户各自导出 wantsOverlay / wantsKeyboard / hitBox 三个只读属性，
//     本窗只做归并，不做判断。
// ============================================================

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.data.state
import qs.ui.bar
import qs.ui.island

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // ---- 框的几何（窗内一切位置的来源）----
    // 顶栏高取灵动岛收起高：顶框才是一条直线，段下不留缺口
    readonly property int barHeight: Size.island.collapsedH
    readonly property int railThickness: 8

    // 多屏只让第一块抢键盘，否则 Exclusive 互抢，Esc 无处可去
    readonly property bool isKeyOwner: {
        const screens = Quickshell.screens
        return screens.length > 0 && modelData === screens[0]
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1

    // 面板只在主屏那份实例化（合并前它们就没套 Variants），所以诉求要过 Loader
    // 取；未挂载时视为「什么都不要」
    readonly property bool panelsWantOverlay: panelsLoader.item
        ? panelsLoader.item.wantsOverlay : false
    readonly property bool panelsWantKeyboard: panelsLoader.item
        ? panelsLoader.item.wantsKeyboard : false

    readonly property bool wantsKeyboard: island.wantsKeyboard || panelsWantKeyboard

    WlrLayershell.namespace: "qsl-frame"
    WlrLayershell.layer: (island.wantsOverlay || panelsWantOverlay)
        ? WlrLayer.Overlay : WlrLayer.Top
    // OnDemand + focus grab，而不是 Exclusive。
    //
    // 先说清一件事，免得再有人顺着旧结论走：**这不是为了性能**。仓库里长期流传
    // 的「申请 Exclusive 要 ~190ms 主线程停顿」是错的。隔离复现（一个空的全屏
    // PanelWindow 反复切 Exclusive，再叠上 FocusScope 夺焦、TextInput 夺焦，
    // QT_IM_MODULE=fcitx 照常开着）三轮全程零掉帧。那 190ms 另有其人，是 QML
    // 的 JS 垃圾回收——显式 gc() 能一发复现出 [156,136]ms，和它一模一样，而且
    // 空闲时永远量不到（见 plan.md 性能审计一轮）。当年那次 A/B 之所以指向
    // 焦点，是因为把 keyboardFocus 钉成 None 顺带让内容不再被激活，分配量掉了
    // 一截，GC 也就没那么容易触发——省掉的从来不是焦点这笔钱。
    //
    // 换过来的真实理由是 grab 白送的两样东西：
    //   1. Exclusive 会把应用键盘焦点抢走且不归还，Island 里那套「记下窗口地址
    //      → 关窗后 spawn hyprctl 还回去」（含两个 Timer）就是为了填这个坑。
    //      grab 从一开始就不抢，坑也不存在
    //   2. cleared = 用户点到框外面去了，这就是「点空白处关面板」。面板自己那张
    //      mask 只盖住贴边那条条带，框外的点击它根本收不到——以前只能靠 Esc
    WlrLayershell.keyboardFocus: root.wantsKeyboard
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    // OnDemand 的语义是「点了才给键盘」，IPC / 快捷键开的面板没人点，所以键盘
    // 得靠这个抓取拿——Hypr 的 focus grab 协议本来就是给启动器这类临时面板用的
    HyprlandFocusGrab {
        active: root.wantsKeyboard
        windows: [root]
        onCleared: Panels.dismissAll()
    }
    // 独占区由 Exclusions 的四个小窗声明，本窗只管画，所以要 Ignore：
    // 否则它会拿整屏去撑位，把所有应用挤没
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // 根区域刻意挂在 leftSeg 上而不是留空：留空的话就要赌「空根区域」是算空
    // 还是算全窗，赌错的代价是整屏点击全被这个全屏窗吃掉。挂一个必须可点的矩形，
    // 其余并上来，两种语义下结果都对。
    // item: 给的是 Item 的几何，会自动换算到窗坐标，所以嵌在子组件里也能直接引用
    mask: Region {
        item: bar.leftSeg
        Region { item: bar.rightSeg }
        Region { item: rails.leftRail }
        Region { item: rails.rightRail }
        Region { item: rails.bottomRail }
        Region { item: island.hitBox }
        Region { item: panelsLoader.item ? panelsLoader.item.leftbarHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.rightbarHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.notifHitBox : null }
    }

    Bar {
        id: bar
        screen: root.screen
        width: root.width
        height: root.barHeight
    }

    Rails {
        id: rails
        anchors.fill: parent
        topOffset: root.barHeight
        // 水波起伏期间让出厚度：波谷就是 waveMin，rail 不缩下去的话波谷被它
        // 填平，起伏只剩向外鼓的半边（RailRipple 里有完整说明）
        thickness: ripple.active ? ripple.waveMin : root.railThickness
    }

    // 岛压在顶栏之上：Hub 展开时它那层「点空白关闭」的面要能盖住段，
    // 这是合并前岛窗在 Overlay 层的既有行为
    IslandShell {
        id: island
        anchors.fill: parent
        z: 10
        isKeyOwner: root.isKeyOwner
    }

    // C/V/N 压在岛之上：合并前它们在 Overlay 层、岛在 Top，就是这个次序
    Loader {
        id: panelsLoader
        anchors.fill: parent
        z: 20
        active: root.isKeyOwner
        sourceComponent: FramePanels {}
    }

    // 开面板时沿整个框跑一趟的鼓包波。压在最上面：它的鼓包要盖过应用窗口边缘
    RailRipple {
        id: ripple
        anchors.fill: parent
        z: 30
        railThickness: root.railThickness
        barHeight: root.barHeight
        leftSegWidth: bar.leftSeg.width
        rightSegWidth: bar.rightSeg.width
    }

    Connections {
        target: Panels
        function onOpened(id, edge) {
            // 只有主屏那份放波：面板本来就只在主屏，别的屏不该跟着抖
            if (root.isKeyOwner)
                ripple.trigger(edge)
        }
    }
}
