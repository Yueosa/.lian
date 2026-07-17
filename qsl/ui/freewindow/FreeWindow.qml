// FreeWindow — 弹出窗口壳
//
// 统一：几何 / 入退场动画 / Esc / 关闭时不挡点击
// 入场 OutBack(0.3) / 退场 InBack(0.1)
//
// 圆角裁切：实心底用 Rectangle.radius 即可；含 Image 的子窗（AppWindow）
// 自己做 OpacityMask。这里不加全窗 layer，避免 1200×700 常驻离屏纹理。

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: true

    // 子内容自动进入卡牌
    default property alias content: card.data

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: shellNamespace
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // 子窗口可覆盖，例如 "qsl-app"
    property string shellNamespace: "qsl-freewindow"

    // ============================================================
    // 几何 (16:9)
    // ============================================================

    readonly property int frameWidth: Math.min(width - 80, Math.max(1100, Math.round(frameHeight * 16 / 9)))
    readonly property int frameHeight: Math.min(700, Math.max(620, height - 120))
    readonly property int closedOffset: Math.round(height * 0.5 + frameHeight * 0.5 + 48)

    // ============================================================
    // 状态
    // ============================================================

    property bool open: false

    // 打开或动画中才参与绘制；子对象仍存在，不需要伪缓存 Timer。
    readonly property bool contentActive: open || anim.slide !== closedOffset

    function toggle() { open ? closeWindow() : openWindow() }
    function openWindow() {
        Island.captureFocus()
        open = true
    }
    function closeWindow() {
        if (!open)
            return
        open = false
        Island.restoreFocus()
    }

    // 关闭时清零 mask，避免挡桌面点击
    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    // ============================================================
    // 动画 — 用 State 绑定 closedOffset，避免首帧 height=0 算死偏移
    // ============================================================

    Item {
        id: anim
        property int slide: root.closedOffset
        state: root.open ? "open" : "closed"

        states: [
            State {
                name: "open"
                PropertyChanges { target: anim; slide: 0 }
            },
            State {
                name: "closed"
                // 关闭态持续绑定当前 closedOffset，屏幕尺寸变化时跟着走
                PropertyChanges { target: anim; slide: root.closedOffset }
            }
        ]

        transitions: [
            Transition {
                from: "closed"; to: "open"
                NumberAnimation {
                    target: anim
                    property: "slide"
                    duration: 500
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            },
            Transition {
                from: "open"; to: "closed"
                NumberAnimation {
                    target: anim
                    property: "slide"
                    duration: 350
                    easing.type: Easing.InBack
                    easing.overshoot: 0.1
                }
            }
        ]
    }

    FocusScope {
        anchors.fill: parent
        enabled: root.open
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
                event.accepted = true
            }
        }

        // 点卡牌外关窗；卡牌本体吞点击，避免点内容穿透关闭
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }

        Rectangle {
            id: card
            width: root.frameWidth
            height: root.frameHeight
            anchors.centerIn: parent
            anchors.verticalCenterOffset: anim.slide
            // 完全关闭且缓存结束后再藏，滑动过程中保持绘制
            visible: root.contentActive
            color: "transparent"
            radius: Size.rounding.xxl
            clip: true

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {}
            }
        }
    }
}
