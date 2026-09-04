// Exclusions — 四个 1×1 隐形窗，只负责向合成器声明独占区
//
// 为什么需要它们：layer-shell 的 exclusiveZone 是**一个整数**，一个 surface
// 只能给它锚定的边留一个值。而我们要留的是「顶 44（bar）+ 左右下各 8（rail）」
// 四个不同的值，所以合并窗自己做不到——它 exclusionMode: Ignore 只管画，
// 撑位这件事拆出来给四个惰性小窗。（同 caelestia 的
// shell/modules/drawers/Exclusions.qml）
//
// 这四个窗是惰性的：1×1、透明、mask 空（不吃任何输入）、不申请焦点、
// 不播动画。它们只是四条给合成器看的声明。
//
// 顺序有讲究：顶边先声明，左右下的独占区才落在 bar 之下。这复刻了合并前
// 「竖 rail margins.top=0，靠 Hyprland 把同层 Normal 面推到 bar 区之下」
// 的效果（见合并前 Rails.qml 的注释）。

import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var screen
    // 顶部 bar 高度（= 灵动岛收起高，顶框才是一条直线）
    required property int barZone
    // 三边 rail 厚度
    required property int railZone

    component Zone: PanelWindow {
        screen: root.screen
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        // 空 Region = 不接受任何输入，点击直接穿到下面
        mask: Region {}
        WlrLayershell.namespace: "qsl-exclusion"
        WlrLayershell.layer: WlrLayer.Top
    }

    Zone {
        anchors.top: true
        exclusiveZone: root.barZone
    }

    Zone {
        anchors.left: true
        exclusiveZone: root.railZone
    }

    Zone {
        anchors.right: true
        exclusiveZone: root.railZone
    }

    Zone {
        anchors.bottom: true
        exclusiveZone: root.railZone
    }
}
