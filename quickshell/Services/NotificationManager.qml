pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Clavis.Notif
import qs.Modules.DynamicIsland.OverviewContent
import qs.config

Item {
    id: root

    // 兼容旧 API：DI 依赖 model / hasNotifs / removeByNotifId
    readonly property var model: NotificationStore.popupModel
    readonly property bool hasNotifs: NotificationStore.popupModel.count > 0

    NotificationServer {
        id: server
        onNotification: (n) => {
            // 媒体类自适应过滤交给 Store；这里只把原始字段平铺成 QVariantMap
            NotificationStore.ingest({
                "id":            n.id,
                "appName":       n.appName,
                "desktopEntry":  n.desktopEntry,
                "summary":       n.summary,
                "body":          n.body,
                "image":         n.image || "",
                "appIcon":       n.appIcon || "",
                "icon":          n.icon || ""
            }, !ControlBackend.dndEnabled);
        }
    }

    function removeByNotifId(targetId) {
        NotificationStore.removePopup(targetId);
    }
}
