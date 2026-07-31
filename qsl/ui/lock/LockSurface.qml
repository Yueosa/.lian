// LockSurface — 每屏一个；鉴权走共享 LockContext
// 背景：Wallpaper 降采样铺满 + 暗色遮罩（不用 FastBlur / 全屏离屏）
// 动画：显式 ParallelAnimation；关锁随 surface 销毁
// 性能：Image async + sourceSize≈960 + cache:false；无 GraphicalEffects

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.data.state

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property var context

    color: Color.surface

    readonly property bool exiting: !!(context && context.dismissing)

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

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: root; property: "wpOpacity"; to: 1
            duration: 320; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "scrimOpacity"; to: 0.55
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
            target: root; property: "scrimOpacity"; to: 0
            duration: 380; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root; property: "wpOpacity"; to: 0
            duration: 400; easing.type: Easing.InCubic
        }
    }

    // 降采样壁纸：靠 sourceSize 软化细节，再叠重遮罩（避免 FastBlur 全屏 FBO）
    Image {
        id: wpImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        mipmap: false
        opacity: root.wpOpacity
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
        Qt.callLater(function () {
            root.playEnter()
            content.focusInput()
        })
    }

    Component.onDestruction: {
        wpImage.source = ""
    }
}
