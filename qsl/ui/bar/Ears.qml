// Ears — 四颗框角凹角衔接耳（14×14 独立小窗，Bottom 层）
//
// 这是合并框窗**唯一没能收进去**的部分，原因是层级：
// 耳朵盖的是应用窗口圆角留下的透明缺口。放 Bottom 层（mpvpaper 在 background，
// bottom 在其上），应用窗口连同它的边框线画在耳朵**之上**，耳朵只从圆角外的
// 缺口透出来，严丝合缝。搬进 Top 层的合并框窗就会反过来——月牙半径 14 比
// Hyprland 的 rounding 大，那圈差会压住窗口边框线。
// 而一个 Wayland surface 只能选一层，所以这四颗留在外面。
//
// 代价：rail 水波扫到四个角时耳朵不跟着亮（它们不在同一棵场景图里）。月牙很细，
// 先这样，真看得出豁口再想办法对齐半径搬进去。
//
// 这四个窗是惰性的：不吃输入、不申请焦点、只在换主题时重画一次。

import Quickshell
import Quickshell.Wayland
import qs.Components

Scope {
    id: root

    required property var screen
    // 顶栏高度：上面两颗耳从这里起
    required property int topOffset
    required property int railThickness

    readonly property int earSize: 14

    component Ear: PanelWindow {
        screen: root.screen
        implicitWidth: root.earSize
        implicitHeight: root.earSize
        color: "transparent"
        WlrLayershell.namespace: "qsl-rail-ear"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
    }

    // 左上：左段 × 左 rail
    Ear {
        anchors { left: true; top: true }
        margins { left: root.railThickness; top: root.topOffset }

        EarCanvas {
            anchors.fill: parent
            corner: EarCanvas.TopRight
        }
    }

    // 右上：右段 × 右 rail
    Ear {
        anchors { right: true; top: true }
        margins { right: root.railThickness; top: root.topOffset }

        EarCanvas {
            anchors.fill: parent
            corner: EarCanvas.TopLeft
        }
    }

    // 左下：左 rail × 底 rail
    Ear {
        anchors { left: true; bottom: true }
        margins { left: root.railThickness; bottom: root.railThickness }

        EarCanvas {
            anchors.fill: parent
            corner: EarCanvas.BottomRight
        }
    }

    // 右下：右 rail × 底 rail
    Ear {
        anchors { right: true; bottom: true }
        margins { right: root.railThickness; bottom: root.railThickness }

        EarCanvas {
            anchors.fill: parent
            corner: EarCanvas.BottomLeft
        }
    }
}
