// RailContainer — 从 rail 派生的内容容器（进入模式的最小单元）
//
// present 驱动派生/收回；收回动画播完才卸载内容（Loader）。
// 派生方式 = 整卡滑入（不是宽度裁切揭示）：
//   宽度裁切会把圆角壳的圆角切成方边，且把内容切出方口（实测反馈）；
//   整卡滑入让圆角随身携带，屏幕边缘/rail 边缘就是天然裁切线
// edge 决定派生方向：
//   left  = 从 leftrail 向右滑入
//   right = 从 rightrail 向左滑入
//   bottom = 从 bottomrail 向上滑入
// 形状：贴 rail 侧直边，外侧两角圆角，贴 rail 侧上下各一颗凹耳。
// 位移取整：分数位移会让内容逐帧重采样（Tray 教训）。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    property string edge: "left"
    property bool present: false
    // 级联延迟：页面框架按容器序号注入，依次派生
    property int staggerMs: 0
    // 显式尺寸；0 = 取内容 implicit 尺寸
    property int naturalWidth: 0
    property int naturalHeight: 0

    property alias sourceComponent: bodyLoader.sourceComponent
    // 页面框架用来给内容连信号（requestClose 等）
    property alias bodyItem: bodyLoader.item

    // 派生进度：0=收回 rail，1=完全展开
    property real progress: 0

    // 尺寸冻结：present 变 false 的瞬间捕获，退出动画期间不再跟内容变
    property int _frozenW: 0
    property int _frozenH: 0

    readonly property int innerW: naturalWidth > 0 ? naturalWidth
        : (present ? bodyLoader.implicitWidth : _frozenW)
    readonly property int innerH: naturalHeight > 0 ? naturalHeight
        : (present ? bodyLoader.implicitHeight : _frozenH)

    // 尺寸生长（island 手感）：宽随 progress 长，内容跟随重排；
    // 取整防分数宽度逐帧重采样（Tray 教训）
    implicitWidth: (edge === "bottom") ? innerW : Math.round(innerW * progress)
    implicitHeight: (edge === "bottom") ? Math.round(innerH * progress) : innerH

    onPresentChanged: {
        if (present) {
            enterDelay.restart()
        } else {
            enterDelay.stop()
            // 冻结此刻尺寸：退出动画按旧尺寸播，内容/高度变化等
            // 新实例派生时才进场（旧版会"内容先变、窗口后演"）
            _frozenW = innerW
            _frozenH = innerH
            progress = 0
        }
    }

    Timer {
        id: enterDelay
        interval: root.staggerMs
        onTriggered: root.progress = 1
    }

    // 打开用 spatial 过冲（打开类别），收回用 accel 离场
    Behavior on progress {
        Anim { type: root.present ? Anim.Spatial : Anim.Exit }
    }

    // 裁切框：左缘 = rail 右缘，是滑入的天然裁切线
    Item {
        id: clipFrame
        x: 0
        y: 0
        width: root.width
        height: root.height
        clip: true

        // 生长体：尺寸跟随 progress，圆角每帧都在（壳随尺寸走）
        Item {
            id: slideBody
            width: root.implicitWidth
            height: root.implicitHeight
            x: 0
            y: 0

            // 背景：贴 rail 侧直边，外侧两角圆角
            Rectangle {
                anchors.fill: parent
                color: Color.background
                topLeftRadius: root.edge === "left" ? 0 : 16
                topRightRadius: root.edge === "right" ? 0 : 16
                bottomLeftRadius: root.edge === "left" ? 0 : 16
                bottomRightRadius: root.edge === "right" ? 0 : 16
            }

            Loader {
                id: bodyLoader
                anchors.fill: parent
                // 收回动画播完才卸载
                active: root.present || root.progress > 0
            }
        }
    }

    // 贴 rail 侧上下衔接耳（接近到位才淡入：接缝只在 x≈0 时存在）
    // TODO: right/bottom 两个方向的耳朵（迁移 V/A/Z/X/N 时补）
    EarCanvas {
        visible: root.edge === "left"
        x: 0
        y: -14
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.BottomRight
    }
    EarCanvas {
        visible: root.edge === "left"
        x: 0
        y: root.height
        width: 14
        height: 14
        opacity: root.progress
        corner: EarCanvas.TopRight
    }
}
