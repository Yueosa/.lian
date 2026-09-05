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

    // 底色透明：进入时桌面短暂可见（锁屏"盖上来"），退出时随整体淡出露出桌面
    color: "transparent"

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
        // 整体"盖上来"：桌面短暂可见 → 锁屏从 1.06 倍落回原位
        // scale 与 hypr windowsIn 同一条 spatial 曲线同一个 500ms
        Anim {
            target: stage; property: "opacity"; to: 1
            type: Anim.Effects
        }
        Anim {
            target: stage; property: "scale"; to: 1
            type: Anim.Spatial
        }
        Anim {
            target: root; property: "wpOpacity"; to: 1
            type: Anim.EffectsSlow
        }
        Anim {
            target: root; property: "scrimOpacity"; to: 0.55
            type: Anim.EffectsSlow
        }
        Anim {
            target: root; property: "chromeOpacity"; to: 1
            type: Anim.EffectsSlow
        }
        Anim {
            target: root; property: "chromeY"; to: 0
            type: Anim.Spatial
        }
    }

    ParallelAnimation {
        id: exitAnim
        // 整体淡出：壁纸/遮罩/控件一起透明，桌面"淡入"显现，
        // 中途不露出任何底色（之前的白屏就是底色外露）
        Anim {
            target: stage; property: "opacity"; to: 0
            type: Anim.Exit
        }
        Anim {
            target: stage; property: "scale"; to: 0.97
            type: Anim.Exit
        }
    }

    // 舞台：所有内容包一层，进入/退出整体做透明度与缩放
    // 初始 opacity 0 + scale 1.06，由 enterAnim 落回
    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        scale: 1.06

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
