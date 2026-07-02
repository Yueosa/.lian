// FreeWindow — 弹出窗口壳
//
// 统一：颜色 / 圆角 / 动画
// 21:9 卡牌从底部滑入，fastIn 曲线

import QtQuick
import Quickshell
import Quickshell.Wayland
import qsl.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qsl-freewindow"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ============================================================
    // 几何 (21:9)
    // ============================================================

    readonly property int frameWidth:  Math.min(width  - 80,  Math.max(1200, Math.round(frameHeight * 21 / 9)))
    readonly property int frameHeight: Math.min(700, Math.max(560,  height - 100))
    readonly property int closedOffset: Math.round(height * 0.5 + frameHeight * 0.5 + 40)

    // ============================================================
    // 状态
    // ============================================================

    property bool open: false
    property bool fadingOut: false   // Enter 启动应用时的退场动画状态

    function toggle()  { open ? closeWindow() : openWindow() }
    function openWindow()   { open = true  }
    function closeWindow()  { open = false; fadingOut = false }
    function quickClose()   { fadingOut = true }  // Enter 启动 → 渐变消失

    // ============================================================
    // 动画 — fastIn (cubic-bezier(0.16, 1, 0.3, 1))
    //
    // 入场: 从底部滑入
    // 退场 (Esc): 从上方滑出
    // 退场 (Enter): 渐变消失 (fadingOut)
    // ============================================================

    property int slide: -closedOffset   // 入场前在屏幕上方（负偏移）

    states: [
        State { name: "open";   PropertyChanges { target: root; slide: 0               } },
        State { name: "closed"; PropertyChanges { target: root; slide: -root.closedOffset } }
    ]
    transitions: [
        Transition {
            from: "closed"; to: "open"
            NumberAnimation { target: root; property: "slide"; duration: Size.anim.smooth; easing: Size.anim.fastIn }
        },
        Transition {
            from: "open"; to: "closed"
            NumberAnimation { target: root; property: "slide"; duration: Size.anim.normal; easing: Size.anim.fastIn }
        }
    ]

    // ============================================================
    // Esc 关闭
    // ============================================================

    FocusScope {
        anchors.fill: parent
        enabled: root.open; focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { root.closeWindow(); e.accepted = true } }
    }

    // ============================================================
    // 卡牌容器 — 子 Item 自动成为此 Rectangle 的子元素
    // ============================================================

    default property alias content: card.data

    Rectangle {
        id: card
        width: root.frameWidth; height: root.frameHeight
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.slide
        color: Qt.rgba(Color.surfaceHigh.r, Color.surfaceHigh.g, Color.surfaceHigh.b, 0.95)
        radius: Size.rounding.xl
        clip: true
        opacity: root.fadingOut ? 0 : 1

        Behavior on opacity {
            enabled: root.fadingOut
            NumberAnimation { duration: Size.anim.normal; easing: Size.anim.fastIn }
        }

        border.color: Color.outlineVariant
        border.width: 1
    }
}
