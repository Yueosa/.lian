// FreeWindow — 通用弹出窗口壳
//     21:9 宽高比，左(60%)壁纸预览 + 右(40%)内容区
//     三个页面复用：app/clip/key，每次只实例化一个
//
// 用法: FreeWindow { contentComponent: myPage; onClosed: ... }

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qsl.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: true
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "qsl-freewindow"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: windowOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // === 几何 (21:9) ===
    readonly property int frameWidth:  Math.min(width  - 80,  Math.max(1200, Math.round(frameHeight * 21 / 9)))
    readonly property int frameHeight: Math.min(700, Math.max(580,  height - 100))
    readonly property int paneWidth:   Math.round(frameWidth * 0.6)
    readonly property int closedOffset: Math.round(height * 0.5 + frameHeight * 0.5 + 48)

    // === 状态 ===
    property bool windowOpen: false
    property var contentComponent

    signal closed()

    function open()  { windowOpen = true  }
    function close() { windowOpen = false; closed() }

    // === 动画 ===
    property int slideOffset: closedOffset
    states: [
        State { name: "open";   PropertyChanges { target: root; slideOffset: 0              } },
        State { name: "closed"; PropertyChanges { target: root; slideOffset: root.closedOffset } }
    ]
    transitions: [
        Transition { from: "closed"; to: "open";
            NumberAnimation { target: root; property: "slideOffset"; duration: Size.anim.smooth; easing.type: Easing.OutBack; easing.overshoot: 0.3 } },
        Transition { from: "open"; to: "closed";
            NumberAnimation { target: root; property: "slideOffset"; duration: Size.anim.normal; easing.type: Easing.InBack; easing.overshoot: 0.1 } }
    ]

    // === 点击背景关闭 ===
    MouseArea { anchors.fill: parent; enabled: root.windowOpen; onClicked: root.close() }

    // === Esc 关闭 ===
    FocusScope { anchors.fill: parent; enabled: root.windowOpen; focus: root.windowOpen
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true } }
    }

    // === 主卡片 ===
    Rectangle {
        width: root.frameWidth; height: root.frameHeight
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.slideOffset
        color: "transparent"
        radius: Size.rounding.xl
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // 左：壁纸预览
            Rectangle {
                Layout.preferredWidth: root.paneWidth
                Layout.fillHeight: true
                color: Color.surfaceHigh
                radius: Size.rounding.xl
                layer.enabled: true; layer.effect: null  // placeholder for mask

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: ""  // wallpaper — TODO
                    asynchronous: true; cache: false
                }

                // 渐变遮罩
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.08) }
                        GradientStop { position: 0.45; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.18) }
                        GradientStop { position: 1.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.48) }
                    }
                }
            }

            // 右：内容区
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Qt.rgba(Color.surfaceHigh.r, Color.surfaceHigh.g, Color.surfaceHigh.b, 0.9)
                clip: true

                Loader {
                    anchors.fill: parent
                    anchors.margins: 20
                    active: root.windowOpen
                    sourceComponent: root.contentComponent
                }
            }
        }

        // 边框
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Color.outlineVariant
            border.width: 2
            radius: Size.rounding.xl
        }
    }
}
