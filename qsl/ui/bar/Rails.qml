// Rails — 左/右/底三边 8px 装饰 rail（窗内 item，plan 第 6 轮起不再自带窗口）
//
// 合并前这是三个 PanelWindow，各自 exclusiveZone: 8、exclusionMode: Normal，
// 靠「Hyprland 把同层 Normal 面推到 bar 的独占区之下」拿到 topOffset。现在位置
// 直接写出来：竖 rail 从顶栏段下方起到底边，底 rail 被两侧让开 8px。
// 撑位交给 ui/frame/Exclusions.qml 的左/右/下三个小窗。
//
// 底 rail 比屏宽短是预期：两角由竖 rail 盖满，同色无缝。
// 四颗框角凹角耳不在这里——它们要压在应用窗口之下，见 Ears.qml。

import QtQuick
import qs.Components
import qs.data.state

Item {
    id: root

    // 顶栏高度：竖 rail 从这里起
    required property int topOffset

    // 恒定 8px。曾经让框窗在开面板时把它压到水波的波谷厚度（"从 8px 里拿出
    // 4px 做起伏"），结果框的接缝——14×14 的凹角耳、顶栏段 r=22 的下外角——
    // 全是按 8px 配的，一缩就露馅。现在水波只往内鼓，不动这 8px，
    // 所以这里也不再需要 Behavior 换档
    required property int thickness

    // 给 FrameWindow 算 mask 用
    readonly property Item leftRail: left
    readonly property Item rightRail: right
    readonly property Item bottomRail: bottom

    Rectangle {
        id: left
        x: 0
        y: root.topOffset
        width: root.thickness
        height: root.height - root.topOffset
        color: Color.background
    }

    Rectangle {
        id: right
        x: root.width - root.thickness
        y: root.topOffset
        width: root.thickness
        height: root.height - root.topOffset
        color: Color.background
    }

    Rectangle {
        id: bottom
        x: root.thickness
        y: root.height - root.thickness
        width: root.width - root.thickness * 2
        height: root.thickness
        color: Color.background
    }
}
