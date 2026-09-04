// FrameWindow — 合并框窗（plan 第 6 轮）
//
// 一个全屏透明窗装下整个「框」：顶栏两段 + 三边 rail（往后还有岛和 C/V/N）。
// 合并前这些是 8 个独立 Wayland surface，跨窗协调天然做不了——rail 水波就死在
// 这上面（面板那个窗没法往 rail 那个窗里画一个像素）。现在它们在同一棵场景图里，
// 共用一个坐标系、一次渲染出。
//
// 三件事分给了三个地方：
//   画    —— 本窗，exclusionMode: Ignore，覆盖整屏（含别人的独占区之下）
//   撑位  —— Exclusions.qml 的四个 1×1 隐形窗（一个 surface 只能声明一个 zone）
//   凹角  —— Ears.qml 的四颗 Bottom 层小窗（要压在应用窗口之下才不遮边框线）
//
// mask 只圈真正要吃点击的矩形（两段 + 三条 rail），其余穿透。合并前 bar 窗没有
// mask，整条 44px 顶栏都吃点击（包括中间空档）；现在中间空档会穿透到桌面，
// 这是修正不是回归。

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.data.state
import qs.ui.bar

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // ---- 框的几何（窗内一切位置的来源）----
    // 顶栏高取灵动岛收起高：顶框才是一条直线，段下不留缺口
    readonly property int barHeight: Size.island.collapsedH
    readonly property int railThickness: 8

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.namespace: "qsl-frame"
    WlrLayershell.layer: WlrLayer.Top
    // 独占区由 Exclusions 的四个小窗声明，本窗只管画，所以要 Ignore：
    // 否则它会拿整屏去撑位，把所有应用挤没
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // 根区域刻意挂在 leftSeg 上而不是留空：留空的话就要赌「空根区域」是算空
    // 还是算全窗，赌错的代价是整屏点击全被这个全屏窗吃掉。挂一个必须可点的矩形，
    // 其余并上来，两种语义下结果都对。
    // item: 给的是 Item 的几何，会自动换算到窗坐标，所以嵌在 rails 里也能直接引用
    mask: Region {
        item: bar.leftSeg
        Region { item: bar.rightSeg }
        Region { item: rails.leftRail }
        Region { item: rails.rightRail }
        Region { item: rails.bottomRail }
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
        thickness: root.railThickness
    }
}
