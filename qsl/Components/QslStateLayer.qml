// QslStateLayer — M3 状态层：在宿主原色之上盖一层同色半透明
//
// 「鼠标在上面」「正按着」不是换一个颜色，是在原来的颜色上加一层。这样底色
// 无论是什么（透明、surfaceContainer、强调色），反馈的强度都是一致的，也不用
// 在每处各写一遍 `hovered ? 某个色 : 另一个色` 的三目。
//
// 用法：贴在要响应的 Rectangle 里，把提供状态的 MouseArea 交给它。
//
//     Rectangle {
//         radius: 8
//         color: Color.surfaceContainer
//         QslStateLayer { source: ma; tint: Color.primary }
//         MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }
//     }
//
// 圆角默认跟着宿主走。宿主不是 Rectangle（没有 radius）时自己给。
//
// 不适用的情形——这几类别硬套，它们不是状态层：
//   · 悬停时**前景**变色（图标/文字转 primary、删除键转 error）——状态层管的是
//     底，这类改的是字。全树剩的 7 处手写 hover 全是这一类，是对的，别去动。
//   · 悬停才显形的隐藏操作（opacity 0 → 1）——那是在说「这里还有东西」
//   · 锁屏（ui/lock）——它浮在模糊壁纸上，用的是写死的白色而非主题色，
//     这里的透明度档是照暗色面调的，套过去偏亮

import QtQuick
import qs.data.state

Rectangle {
    id: root

    // 提供 containsMouse / pressed 的那个 MouseArea。给 null 就只看 selected。
    property Item source: null
    // 叠加色。透明底上用 Color.primary，有底色的行上用 Color.text。
    property color tint: Color.text
    // 用强调档的透明度（更重）。透明底的按钮/芯片该开。
    property bool accent: false
    // 选中不随鼠标走，且比悬停重
    property bool selected: false
    // 整层关掉（禁用态、非交互行）
    property bool active: true

    readonly property bool _hovered:
        root.active && !!root.source && !!root.source.containsMouse
    readonly property bool _pressed:
        root.active && !!root.source && !!root.source.pressed

    readonly property real _alpha: {
        if (!root.active)
            return 0
        if (root._pressed)
            return root.accent ? Color.state.pressedAccent : Color.state.pressed
        if (root.selected)
            return Color.state.selected
        if (root._hovered)
            return root.accent ? Color.state.hoverAccent : Color.state.hover
        return 0
    }

    anchors.fill: parent
    // 宿主是 Rectangle 就跟它的圆角，否则调用方自己给
    radius: parent && parent.radius !== undefined ? parent.radius : 0
    color: Color.withAlpha(root.tint, root._alpha)

    // z 保持默认 0，**靠声明顺序压在内容下面**——所以它必须写在文字/图标
    // 那些兄弟节点前面。
    //
    // 别想着用 z: -1 躲开这个约束：QML 的渲染顺序是「z<0 的子项 → 本体 →
    // z>=0 的子项」，负 z 会跑到宿主自己的填充色底下，直接看不见。

    Behavior on color {
        CAnim { type: CAnim.Theme }
    }
}
