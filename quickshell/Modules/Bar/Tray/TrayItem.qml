import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config

MouseArea {
    id: root
    required property var modelData 

    readonly property string trayIconLower: (root.modelData.icon || "").toLowerCase()
    readonly property string trayIdLower: (root.modelData.id || "").toLowerCase()
    readonly property string trayTitleLower: (root.modelData.tooltipTitle || "").toLowerCase()
    
    // 保持 20x20 的尺寸，完美适配 36px 高度的药丸背景
    implicitWidth: 20
    implicitHeight: 20
    
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function detectBundledAppId() {
        const parts = [
            (root.modelData.icon || "").toLowerCase(),
            (root.modelData.id || "").toLowerCase(),
            (root.modelData.tooltipTitle || "").toLowerCase()
        ];
        const haystack = parts.join(" ");

        if (haystack.indexOf("telegram") >= 0)
            return "telegram";
        if (haystack.indexOf("wechat") >= 0 || haystack.indexOf("weixin") >= 0)
            return "wechat";
        if (haystack.indexOf("discord") >= 0)
            return "discord";
        if (haystack.indexOf("linuxqq") >= 0 || haystack.indexOf("tim") >= 0)
            return "qq";

        return "";
    }

    function bundledIconPath(appId) {
        if (!appId)
            return "";
        return "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/apps/" + appId + ".svg";
    }

    function closeMenu() {
        if (trayMenu.visible) {
            trayMenu.visible = false
        }
    }

    function closeOtherMenus() {
        var siblings = root.parent.children
        for (var i = 0; i < siblings.length; i++) {
            var sibling = siblings[i]
            if (sibling === root) continue
            if (typeof sibling.closeMenu === "function") {
                sibling.closeMenu()
            }
        }
    }

    onClicked: (event) => {
        if (event.button === Qt.LeftButton) {
            modelData.activate();
            trayMenu.visible = false;
        } else if (event.button === Qt.RightButton) {
            if (!trayMenu.visible) {
                closeOtherMenus()
                trayMenu.visible = true
            } else {
                trayMenu.visible = false
            }
        }
    }

    TrayMenu {
        id: trayMenu
        
        rootMenuHandle: root.modelData.menu
        trayName: root.modelData.tooltipTitle || root.modelData.id || "Menu"
        
        anchor.item: root
        anchor.rect.y: (root.mapToItem(null, 0, 0).y > 500) ? -trayMenu.implicitHeight - 5 : root.height + 5
        anchor.rect.x: 0
    }

    Image {
        id: content
        anchors.fill: parent
        
        source: {
            const appId = root.detectBundledAppId();
            if (appId)
                return root.bundledIconPath(appId);

            const raw = root.modelData.icon;
            if (!raw) return "";
            // 绝对路径 / 已带 scheme：直接用，避免被任何 fallback 覆盖
            if (raw.startsWith("/") || raw.startsWith("file://") || raw.startsWith("image://"))
                return raw;
            // 裸图标名 → 走 quickshell IconImageProvider 解析系统主题
            return "image://icon/" + raw;
        }

        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true

        opacity: 0.0
    }

    MultiEffect {
        anchors.fill: content
        source: content
        visible: content.status !== Image.Error

        // 保持应用原有图标颜色，仅补一个弱阴影避免浅色主题下“白图标隐身”。


        shadowEnabled: true
        shadowColor: Qt.rgba(Colorscheme.shadow.r, Colorscheme.shadow.g, Colorscheme.shadow.b, 0.55)
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 1
        shadowBlur: 0.5

        opacity: root.containsMouse ? 1.0 : 0.88
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        visible: content.status === Image.Error || (!root.modelData.icon)
        text: (root.trayIconLower.indexOf("fcitx") >= 0 || root.trayIdLower.indexOf("fcitx") >= 0 || root.trayTitleLower.indexOf("fcitx") >= 0)
            ? "keyboard"
            : ((root.trayIconLower.indexOf("network-wired") >= 0) ? "lan" : "apps")
        color: Colorscheme.on_surface
        font.family: Sizes.fontIcon
        font.pixelSize: Sizes.font.xl
    }
}
