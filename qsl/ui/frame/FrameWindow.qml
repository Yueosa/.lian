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
    // QT_IM_MODULE=fcitx 照常开着，并用 activeFocus 确认焦点真的交付了）三轮
    // 全程零掉帧。
    //
    // 那 190ms 另有其人，已定案：TrayMenu 里一份**菜单关着也不解除**的 dbusmenu
    // 订阅。托盘应用会跟着我们的键盘焦点变化重发 LayoutUpdated，我们就去拉一次
    // GetLayout，回复到达时把整棵闭合菜单的委托树重建一遍（每个 Text 走一趟
    // HarfBuzz）。所以「焦点」只是触发器，钱花在那棵看不见的菜单上——见
    // TrayMenu.qml 里 rootOpener 的注释和 plan.md 第 6 轮。当年那次 A/B 之所以
    // 指向焦点，是因为钉成 None 之后焦点从此不再交付，整条链子跟着断了。
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
        Region { item: panelsLoader.item ? panelsLoader.item.launcherHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.clipboardHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.tilesHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.powerHitBox : null }
        Region { item: panelsLoader.item ? panelsLoader.item.noteHitBox : null }
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
        // 恒定 8px，水波期间也不动。曾经让它缩到波谷厚度以便"从 8px 里拿出
        // 4px 做起伏"，结果框的接缝（14×14 的凹角耳、段的 r=22 下外角）全是
        // 按 8px 配的，一缩就露馅 —— 详见 RailRipple.waveMin 的注释
        thickness: root.railThickness
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

    // 框边水波。z 压在**所有租户之下**（顶栏、rail、岛、面板）。
    //
    // z 调过两次，两次的理由都值得记：
    //
    // 一、最早给的是 z: 30（最上层），理由写的是"鼓包要盖过应用窗口边缘"。那个
    // 理由本身是糊涂的——应用窗口在**另一个 Wayland surface** 上、整个在框窗之
    // 下，窗内 z 序跟它没有半点关系；z 只决定水波和我们**自己**这几个租户谁盖谁。
    // 而算一下就知道压在最上面是错的：面板卡片的边缘离屏幕边正好 8px，水波常驻
    // 波峰 16px、行波峰值 20px，都从屏幕边量起——于是波每次经过，都是一条
    // 12~20px 宽的背景色横扫过卡片边缘。用户报的"水波蔓延到 RightBar 的时候卡卡
    // 的"就是这个，不是掉帧（左右两侧实测都是稳定 16ms、零掉帧）。
    //
    // 二、然后是 z: 1（rail 之上、面板之下）。顶栏并进水波之后不行了：顶栏那两
    // 条带为了不掐零，实心底那 8px 是**藏在栏里**的（见 RailRipple 里 Strip 的
    // 注释），得靠顶栏自己盖住；压在栏之上的话那 8px 就会糊在栏的下边缘上，
    // 顶栏的内容是 verticalCenter 对齐的，够高的东西会被它啃掉一截。
    // 压到最底之后语义也最顺：rail 和顶栏是框，水波是框里的水，面板和岛是坐在
    // 框上的东西——水从它们全部的背后过去
    RailRipple {
        id: ripple
        anchors.fill: parent
        z: -1
        railThickness: root.railThickness
        barHeight: root.barHeight
        leftSegWidth: bar.leftSeg.width
        rightSegWidth: bar.rightSeg.width
        // 只有主屏那份放波：面板本来就只在主屏，别的屏不该跟着抖。
        // 以前这条写在一个 onOpened 的 Connections 里（水波靠信号触发），现在
        // 水波直接读 Panels.railSlots 自己决定，所以门禁也得挪进它的输入
        keyOwner: root.isKeyOwner
    }
}
