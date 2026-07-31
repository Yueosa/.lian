// LockSurface — 每屏一个；鉴权走共享 LockContext
// 背景：Wallpaper 降采样 + FastBlur + 暗色遮罩
// 动画：显式 ParallelAnimation（不用 Behavior，避免退出时被立刻销毁/看不出）
// 性能：Image async + sourceSize；blur 缩小源；关锁随 surface 销毁

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.data.state

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var context

    color: Color.surface

    readonly property bool exiting: !!(context && context.dismissing)

    property real blurRadius: 0
    property real scrimOpacity: 0
    property real chromeOpacity: 0
    property real chromeY: 48
    property real wpOpacity: 0

    function tryUnlock() {
        if (root.exiting)
            return
        root.context.tryUnlock(content.passwordText())
    }

    function playEnter() {
        exitAnim.stop()
        enterAnim.restart()
    }

    function playExit() {
        enterAnim.stop()
        exitAnim.restart()
    }

    onExitingChanged: {
        if (exiting)
            playExit()
    }

    // 进锁：沉入（自下上移 + blur 抬升）
    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root; property: "wpOpacity"; to: 1
            duration: 320; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "blurRadius"; to: 48
            duration: 380; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "scrimOpacity"; to: 0.52
            duration: 360; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "chromeOpacity"; to: 1
            duration: 340; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "chromeY"; to: 0
            duration: 380; easing.type: Easing.OutCubic
        }
    }

    // 出锁：掀开（上移淡出 + blur/遮罩回落）——幅度加大，避免「没看见」
    ParallelAnimation {
        id: exitAnim
        NumberAnimation {
            target: root; property: "chromeOpacity"; to: 0
            duration: 280; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "chromeY"; to: -56
            duration: 360; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "blurRadius"; to: 0
            duration: 400; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "scrimOpacity"; to: 0
            duration: 380; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "wpOpacity"; to: 0
            duration: 400; easing.type: Easing.InCubic
        }
    }

    Item {
        id: wpSource
        width: 480
        height: Math.max(1, Math.round(480 * root.height / Math.max(1, root.width)))
        visible: false
        layer.enabled: true

        Image {
            id: wpImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: false
            sourceSize.width: 960
            property int fallbackStage: 0
            source: {
                if (fallbackStage <= 0)
                    return Wallpaper.preview
                if (fallbackStage === 1)
                    return Wallpaper.current
                return ""
            }
            onStatusChanged: {
                if (status === Image.Error && fallbackStage < 2)
                    fallbackStage += 1
            }
        }
    }

    FastBlur {
        anchors.fill: parent
        source: wpSource
        radius: root.blurRadius
        opacity: root.wpOpacity
        transparentBorder: false
        visible: wpImage.status === Image.Ready || wpImage.fallbackStage > 0
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.scrimOpacity)
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: {
            if (!root.exiting)
                content.focusInput()
        }
    }

    LockContent {
        id: content
        anchors.fill: parent
        opacity: root.chromeOpacity
        transform: Translate { y: root.chromeY }
        unlocking: root.context.unlockInProgress
        failed: root.context.showFailure
        dismissing: root.exiting

        onSubmit: root.tryUnlock()
    }

    Connections {
        target: root.context
        function onUnlocked() {
            content.clearInput()
        }
        function onAuthFailed() {
            content.clearInput()
            content.focusInput()
            content.shakePassword()
        }
    }

    Component.onCompleted: {
        // 下一帧再进场，保证初始值已提交到场景图
        Qt.callLater(function () {
            root.playEnter()
            content.focusInput()
        })
    }
}
