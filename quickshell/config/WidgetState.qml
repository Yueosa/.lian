pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    readonly property var qsViews: ["network", "bluetooth",  "audio", "updates"]
    readonly property var leftSidebarViews: ["lianclaw", "sys", "weather"]

    // QuickSettings 面板
    property bool qsOpen: false
    property string qsView: "network"

    // 左侧边栏
    property bool leftSidebarOpen: false
    property string leftSidebarView: "lianclaw" // "lianclaw" | "sys" | "weather"

    // 通知面板 UI 状态（数据真源在 Clavis.Notif.NotificationStore）
    property bool notifOpen: false
    property bool notifIsHovered: false
    property bool notifPinned: false
    property string notifCurrentView: "main"
    property string notifDetailAppId: ""
    property string notifDisplayMode: "compact"

    // 热角
    property bool hotCornerEnabled: true

    // 覆盖层策略: partial(Game) | full(DeskTop) | none(专注模式)
    property string overlayMode: "partial"
    readonly property var overlayModes: ["partial", "full", "none"]
    property int overlayRemapSerial: 0

    function normalizeView(view, views, fallback) {
        return views.indexOf(view) !== -1 ? view : fallback;
    }

    function cycleView(current, views, step) {
        if (views.length === 0)
            return current;

        const currentIndex = views.indexOf(current);
        const startIndex = currentIndex === -1 ? 0 : currentIndex;
        return views[(startIndex + step + views.length) % views.length];
    }

    function openQuickSettings(view) {
        qsView = normalizeView(view, qsViews, qsViews[0]);
        qsOpen = true;
    }

    function toggleQuickSettings(view) {
        if (view !== undefined && view !== "") {
            const targetView = normalizeView(view, qsViews, qsViews[0]);
            if (qsOpen && qsView === targetView) {
                qsOpen = false;
                return;
            }
            qsView = targetView;
            qsOpen = true;
            return;
        }

        qsOpen = !qsOpen;
    }

    function cycleQuickSettings(step) {
        qsView = cycleView(qsView, qsViews, step);
        qsOpen = true;
    }

    function openLeftSidebar(view) {
        leftSidebarView = normalizeView(view, leftSidebarViews, leftSidebarViews[0]);
        leftSidebarOpen = true;
    }

    function toggleLeftSidebar(view) {
        if (view !== undefined && view !== "") {
            const targetView = normalizeView(view, leftSidebarViews, leftSidebarViews[0]);
            if (leftSidebarOpen && leftSidebarView === targetView) {
                leftSidebarOpen = false;
                return;
            }
            leftSidebarView = targetView;
            leftSidebarOpen = true;
            return;
        }

        leftSidebarOpen = !leftSidebarOpen;
    }

    function cycleLeftSidebar(step) {
        leftSidebarView = cycleView(leftSidebarView, leftSidebarViews, step);
        leftSidebarOpen = true;
    }

    function openNotifPanelFromHotCorner() {
        if (hotCornerEnabled && !notifOpen) {
            notifOpen = true;
        }
    }

    function normalizeOverlayMode(mode) {
        return overlayModes.indexOf(mode) !== -1 ? mode : "partial";
    }

    function setOverlayMode(mode) {
        const nextMode = normalizeOverlayMode(mode);
        if (overlayMode !== nextMode) {
            overlayMode = nextMode;
            overlayRemapSerial += 1;
        }
        return overlayMode;
    }

    function nextOverlayMode() {
        const index = overlayModes.indexOf(overlayMode);
        return setOverlayMode(overlayModes[(index + 1 + overlayModes.length) % overlayModes.length]);
    }

    function toggleOverlayMode() {
        return nextOverlayMode();
    }

    function cycleOverlayMode() {
        return nextOverlayMode();
    }

    function overlayModeLabel() {
        if (overlayMode === "full") return "桌面模式";
        if (overlayMode === "none") return "专注模式";
        return "游戏模式";
    }

    function shouldOverlayTransient(active) {
        if (overlayMode === "none") return false;
        if (overlayMode === "full") return true;
        return !!active;
    }

    function shouldOverlayPanel(active) {
        return shouldOverlayTransient(active);
    }

    function shouldOverlayIsland(active) {
        return shouldOverlayTransient(active);
    }

    function shouldOverlayPersistent() {
        return overlayMode === "full";
    }
}
