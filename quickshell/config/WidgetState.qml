pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // QuickSettings 面板
    property bool qsOpen: false
    property string qsView: "network"

    // 左侧边栏
    property bool leftSidebarOpen: false
    property string leftSidebarView: "sys" // "sys" | "weather"

    // 通知面板 UI 状态（数据真源在 Clavis.Notif.NotificationStore）
    property bool notifOpen: false
    property bool notifIsHovered: false
    property bool notifPinned: false
    property string notifCurrentView: "main"
    property string notifDetailAppId: ""
    property string notifDisplayMode: "compact"

    // 热角
    property bool hotCornerEnabled: true
    function openNotifPanelFromHotCorner() {
        if (hotCornerEnabled && !notifOpen) {
            notifOpen = true;
        }
    }
}
