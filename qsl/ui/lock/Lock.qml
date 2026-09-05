// Lock — SessionLock 入口
// 解锁成功：先播出场动画，结束后再 locked=false
// 性能：无常驻 Timer；仅 dismiss 时短时 Timer

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.data.service

Scope {
    id: root

    property string _dismissReason: ""

    // 与 LockSurface exitAnim 对齐（略长于动画，避免截断）
    readonly property int dismissMs: 250

    function lock() {
        if (sessionLock.locked)
            return "ALREADY_LOCKED"
        dismissTimer.stop()
        lockCtx.dismissing = false
        lockCtx.currentText = ""
        lockCtx.showFailure = false
        lockCtx.unlockInProgress = false
        sessionLock.locked = true
        console.info("[lock] locked=", sessionLock.locked, " secure=", sessionLock.secure)
        return "LOCKED"
    }

    function isLocked() {
        return sessionLock.locked
    }

    function releaseLock(reason) {
        console.info("[lock] release reason=", reason, " locked=", sessionLock.locked)
        sessionLock.locked = false
        if (sessionLock.locked)
            sessionLock.unlock()
        lockCtx.dismissing = false
        console.info("[lock] after release locked=", sessionLock.locked)
    }

    function beginDismiss(reason) {
        if (lockCtx.dismissing)
            return
        _dismissReason = reason || "ok"
        lockCtx.dismissing = true
        dismissTimer.restart()
    }

    Timer {
        id: dismissTimer
        interval: root.dismissMs
        repeat: false
        onTriggered: root.releaseLock(root._dismissReason)
    }

    LockContext {
        id: lockCtx
        onUnlocked: root.beginDismiss("ok")
    }

    Component.onCompleted: Avatar.ensure()

    WlSessionLock {
        id: sessionLock
        surface: Component {
            LockSurface {
                lock: sessionLock
                context: lockCtx
            }
        }
    }
}
