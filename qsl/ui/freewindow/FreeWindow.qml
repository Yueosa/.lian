// FreeWindow — 弹出窗口壳
//
// 统一：颜色 / 圆角 / 动画 / 焦点管理
// 原 qs Launcher 的动画曲线：入场 OutBack(0.3) / 退场 InBack(0.1)

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.data.state

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
    // 几何 (16:9)
    // ============================================================

    readonly property int frameWidth:  Math.min(width  - 80, Math.max(1100, Math.round(frameHeight * 16 / 9)))
    readonly property int frameHeight: Math.min(700, Math.max(620,  height - 120))
    readonly property int closedOffset: Math.round(height * 0.5 + frameHeight * 0.5 + 48)

    // ============================================================
    // 状态
    // ============================================================

    property bool open: false

    function toggle()        { open ? closeWindow() : openWindow() }
    function openWindow()    { open = true }
    function closeWindow()   { open = false }

    // ============================================================
    // 动画 — 原 qs Launcher 曲线
    //     入场: 从下方滑入, OutBack overshoot=0.3
    //     退场: 向下方滑出, InBack overshoot=0.1
    // ============================================================

    property int slide: closedOffset

    Behavior on slide {
        NumberAnimation { duration: open ? 500 : 350; easing.type: open ? Easing.OutBack : Easing.InBack; easing.overshoot: open ? 0.3 : 0.1 }
    }

    onOpenChanged: slide = open ? 0 : closedOffset

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
    // 卡牌容器（子元素自动成为 card 的子元素）
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

        border.color: Color.outlineVariant
        border.width: 1
    }
}
