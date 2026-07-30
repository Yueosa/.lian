// LockSurface — 锁屏表面（每个屏幕一个实例）
// 自带 PAM 鉴权逻辑，自包含无外部依赖
//
// 性能：
//   - 纯色背景，零 GPU shader
//   - PamContext 按需 start，无轮询
//   - Timer 1s 更新时间（仅 Text.text 变更，无 layout 重算）

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.data.state

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock

    property bool unlocking: false
    property bool showFailure: false

    color: Color.surface

    function tryUnlock() {
        const pwd = content.currentText
        if (pwd === "" || unlocking)
            return
        unlocking = true
        showFailure = false
        pam.start()
    }

    PamContext {
        id: pam
        configDirectory: Qt.resolvedUrl("pam").toString().replace("file://", "")
        config: "password.conf"

        onPamMessage: {
            if (responseRequired)
                respond(content.currentText)
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                content.clearInput()
                root.showFailure = false
                root.lock.unlock()
            } else {
                content.clearInput()
                root.showFailure = true
            }
            root.unlocking = false
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: content.focusInput()
    }

    LockContent {
        id: content
        anchors.centerIn: parent
        width: Math.min(400, parent.width - 80)
        height: parent.height
        unlocking: root.unlocking
        failed: root.showFailure

        onSubmit: root.tryUnlock()
    }
}
