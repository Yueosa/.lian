// Lock — SessionLock 锁屏入口
// 轻量级实现：纯色背景 + 时间 + 密码输入框
// 不做 ScreencopyView/blur，省 ~100MB VRAM
//
// 性能：
//   - WlSessionLock 只在 locked=true 时创建 surface
//   - PamContext 一次性鉴权，无轮询
//   - 无 Image/blur/layer.enabled

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.data.state

Scope {
    id: root

    function lock() {
        if (sessionLock.locked)
            return "ALREADY_LOCKED"
        sessionLock.locked = true
        return "LOCKED"
    }

    function isLocked() {
        return sessionLock.locked
    }

    WlSessionLock {
        id: sessionLock

        surface: Component {
            LockSurface {
                lock: sessionLock
            }
        }
    }
}
