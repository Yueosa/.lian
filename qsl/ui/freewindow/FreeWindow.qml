// FreeWindow — 弹出窗口壳
//
// 统一：几何 / 入退场动画 / Esc / 关闭时不挡点击
// 入场 Anim.Spatial（curveSpatial 过冲）/ 退场 Anim.Exit（curveAccel 加速）
//
// 关态 visible 保持 true：IPC 开/关若卸 layer 会同步建/拆全屏缓冲，
// 表现为「卡一下再播动画」。关态靠 mask=0 不挡点击。
// 圆角裁切由子窗自己做；此处不加全窗 layer。

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Components
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
    // 退场滑完前保持 Exclusive，避免一关就卸焦点抢 client
    WlrLayershell.keyboardFocus: contentActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
    // closeWindow 后等滑出结束再还焦点
    property bool _pendingFocusRestore: false

    // 打开或滑动中：用于键盘焦点 / 子窗 OpacityMask 等
    readonly property bool contentActive: open || anim.slide !== closedOffset

    onContentActiveChanged: {
        if (!contentActive && _pendingFocusRestore) {
            _pendingFocusRestore = false
            Island.restoreFocus()
        }
    }

    function toggle() { open ? closeWindow() : openWindow() }
    function openWindow() {
        _pendingFocusRestore = false
        Island.captureFocus()
        open = true
    }
    function closeWindow() {
        if (!open)
            return
        open = false
        _pendingFocusRestore = true
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
                Anim {
                    target: anim
                    property: "slide"
                    type: Anim.Spatial
                }
            },
            Transition {
                from: "open"; to: "closed"
                Anim {
                    target: anim
                    property: "slide"
                    type: Anim.Exit
                }
            }
        ]
    }

    FocusScope {
        anchors.fill: parent
        enabled: root.contentActive
        focus: root.contentActive
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
