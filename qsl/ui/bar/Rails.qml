// Rails — 左/右/底三边 8px 装饰 rail + 四颗框角衔接耳
// 各吃 8px exclusive zone；竖 rail 从顶栏段下方起到底边
// 竖 rail margins.top=0：Hyprland 会把同层 Normal 面推到 bar 的 exclusiveZone
//   之下，正好落在段底（曾经 margin 44 叠在 zone 上变成 88）
// 底 rail 被两侧 rail 的 exclusive zone 挤短是预期：两角由竖 rail 盖满，同色无缝
// exclusionMode 必须 Normal：Ignore 不注册自己的 8px 预留，窗口会压 rail
// 衔接耳是独立的 14×14 小窗，放 Bottom 层（mpvpaper 在 background，bottom 在其上）：
//   耳朵区与窗口圆角（rounding 12）重叠，Bottom 层透过圆角透明区显形，
//   若在 Top 层会压住窗口边框线

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Components
import qs.data.state

Variants {
    model: Quickshell.screens

    Scope {
        id: railScope
        required property var modelData

        readonly property int thickness: 8
        readonly property int topOffset: Size.island.collapsedH   // 与 Bar.segHeight 对齐
        readonly property int earSize: 14

        // 左竖 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { left: true; top: true; bottom: true }
            margins { top: 0 }   // bar 的 exclusiveZone 已提供段高偏移，再加会叠两次
            implicitWidth: railScope.thickness
            exclusiveZone: railScope.thickness
            color: Color.background
            WlrLayershell.namespace: "qsl-rail-left"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Normal
        }

        // 右竖 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { right: true; top: true; bottom: true }
            margins { top: 0 }   // bar 的 exclusiveZone 已提供段高偏移，再加会叠两次
            implicitWidth: railScope.thickness
            exclusiveZone: railScope.thickness
            color: Color.background
            WlrLayershell.namespace: "qsl-rail-right"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Normal
        }

        // 底 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { left: true; right: true; bottom: true }
            implicitHeight: railScope.thickness
            exclusiveZone: railScope.thickness
            color: Color.background
            WlrLayershell.namespace: "qsl-rail-bottom"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Normal
        }

        // 左上：左段 × 左 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { left: true; top: true }
            margins { left: railScope.thickness; top: railScope.topOffset }
            implicitWidth: railScope.earSize
            implicitHeight: railScope.earSize
            color: "transparent"
            WlrLayershell.namespace: "qsl-rail-ear"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            EarCanvas {
                anchors.fill: parent
                corner: EarCanvas.TopRight
            }
        }

        // 右上：右段 × 右 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { right: true; top: true }
            margins { right: railScope.thickness; top: railScope.topOffset }
            implicitWidth: railScope.earSize
            implicitHeight: railScope.earSize
            color: "transparent"
            WlrLayershell.namespace: "qsl-rail-ear"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            EarCanvas {
                anchors.fill: parent
                corner: EarCanvas.TopLeft
            }
        }

        // 左下：左 rail × 底 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { left: true; bottom: true }
            margins { left: railScope.thickness; bottom: railScope.thickness }
            implicitWidth: railScope.earSize
            implicitHeight: railScope.earSize
            color: "transparent"
            WlrLayershell.namespace: "qsl-rail-ear"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            EarCanvas {
                anchors.fill: parent
                corner: EarCanvas.BottomRight
            }
        }

        // 右下：右 rail × 底 rail
        PanelWindow {
            screen: railScope.modelData
            anchors { right: true; bottom: true }
            margins { right: railScope.thickness; bottom: railScope.thickness }
            implicitWidth: railScope.earSize
            implicitHeight: railScope.earSize
            color: "transparent"
            WlrLayershell.namespace: "qsl-rail-ear"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            EarCanvas {
                anchors.fill: parent
                corner: EarCanvas.BottomLeft
            }
        }
    }
}
