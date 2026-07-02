pragma Singleton

// ============================================================
// 通知服务 — Notification
// ============================================================
// 监听系统 D-Bus 通知（freedesktop.org Notification 协议）。
// Quickshell 原生的 NotificationServer + trackedNotifications 模型
// 已提供去重、排序、持久化追踪，无需额外 C++ 插件或 SQLite。
// DND（免打扰）状态由本服务管理，UI 只读写。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   trackedNotifications  model   被追踪的通知列表
//   hasNotifications      bool    是否有通知
//   count                 int     通知数量
//
// 属性（可读写）：
//   dndEnabled            bool    免打扰模式（true = 新通知静默接收但不触发 UI 弹窗）
//
// 方法：
//   dismiss(id)           关闭指定通知
//   dismissAll()          关闭全部通知
//   toggleDnd()           切换免打扰
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // ============================================================
    // 通知服务器
    //    开启全部能力支持（image/actions/inlineReply）
    //    keepOnReload = true → qs reload 后通知不丢
    // ============================================================

    readonly property var trackedNotifications: server.trackedNotifications
    readonly property bool hasNotifications: trackedNotifications.count > 0
    readonly property int count: trackedNotifications.count

    property bool dndEnabled: false

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyImagesSupported: true
        actionsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            // 收到新通知时自动追踪，防止应用自己关掉后通知也消失
            notification.tracked = true
        }
    }

    // ============================================================
    // 操作
    // ============================================================

    function dismiss(id) {
        for (let i = 0; i < trackedNotifications.count; i++) {
            const n = trackedNotifications.get(i)
            if (n && n.id === id) {
                n.tracked = false
                return
            }
        }
    }

    function dismissAll() {
        for (let i = trackedNotifications.count - 1; i >= 0; i--) {
            const n = trackedNotifications.get(i)
            if (n) n.tracked = false
        }
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled
    }
}
