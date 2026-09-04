// Frame — 每块屏幕一套：合并框窗 + 四个撑位窗 + 四颗凹角耳窗
//
// 三者的分工见 FrameWindow.qml 顶部。这里只负责按屏派生并把几何常量对齐——
// 撑位窗声明的独占区必须和框窗里画的位置一致，不然框会和应用窗口错位，
// 所以两边都从 FrameWindow 的 barHeight / railThickness 取值。

import Quickshell
import qs.ui.bar

Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property var modelData

        Exclusions {
            screen: scope.modelData
            barZone: frame.barHeight
            railZone: frame.railThickness
        }

        FrameWindow {
            id: frame
            modelData: scope.modelData
        }

        Ears {
            screen: scope.modelData
            topOffset: frame.barHeight
            railThickness: frame.railThickness
        }
    }
}
