// LockContext — 共享鉴权（多屏共用一个 PamContext）
// dismissing：出场动画中；各 surface 绑定此标志播退出动效
// 性能：无常驻 Timer；鉴权中 10s 超时

import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string lastError: ""
    property bool pamReplied: false
    property bool dismissing: false

    signal unlocked()
    signal authFailed()

    onCurrentTextChanged: showFailure = false

    function finishFail(err) {
        authTimeout.stop()
        if (!unlockInProgress)
            return
        lastError = err || lastError
        currentText = ""
        showFailure = true
        unlockInProgress = false
        pamReplied = false
        authFailed()
    }

    function emergencyUnlock() {
        authTimeout.stop()
        if (pam.active)
            pam.abort()
        currentText = ""
        showFailure = false
        lastError = ""
        unlockInProgress = false
        pamReplied = false
        console.warn("[lock] emergencyUnlock")
        unlocked()
    }

    function tryUnlock(password) {
        if (dismissing)
            return
        const pwd = (password !== undefined && password !== null && password !== "")
            ? password
            : currentText
        if (pwd === "" || unlockInProgress)
            return

        currentText = pwd
        unlockInProgress = true
        showFailure = false
        lastError = ""
        pamReplied = false

        console.info("[lock] tryUnlock user=", pam.user, " pwdLen=", pwd.length)

        if (pam.active)
            pam.abort()

        if (!pam.start()) {
            console.warn("[lock] pam.start() failed")
            finishFail("start_failed")
            return
        }
        authTimeout.restart()
    }

    Timer {
        id: authTimeout
        interval: 10000
        repeat: false
        onTriggered: {
            if (!root.unlockInProgress)
                return
            console.warn("[lock] auth timeout")
            if (pam.active)
                pam.abort()
            root.finishFail("timeout")
        }
    }

    PamContext {
        id: pam
        // 自有 conf，不依赖 hyprlock 包自带的 /etc/pam.d/hyprlock
        configDirectory: Quickshell.shellDir + "/ui/lock/pam"
        config: "password.conf"
        user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

        function replyIfNeeded() {
            if (!responseRequired || root.pamReplied)
                return
            root.pamReplied = true
            pam.respond(root.currentText)
        }

        onPamMessage: replyIfNeeded()
        onResponseRequiredChanged: {
            if (responseRequired)
                replyIfNeeded()
        }

        onCompleted: result => {
            authTimeout.stop()
            console.info("[lock] pam completed=", PamResult.toString(result))
            if (result === PamResult.Success) {
                if (!root.unlockInProgress)
                    return
                root.currentText = ""
                root.showFailure = false
                root.lastError = ""
                root.unlockInProgress = false
                root.pamReplied = false
                root.unlocked()
            } else {
                root.finishFail(PamResult.toString(result))
            }
        }

        onError: err => {
            console.warn("[lock] pam error=", PamError.toString(err))
            root.lastError = PamError.toString(err)
        }
    }
}
