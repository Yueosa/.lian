// TrayItem — 托盘图标；左键 activate，右键自定义菜单
// 图标：bundled 社交 SVG → 绝对/file/image → image://icon → Material 回退

import QtQuick
import Quickshell
import qs.data.state
import qs.data.service

MouseArea {
    id: root
    required property var modelData

    signal pinChanged

    readonly property string trayIconLower: (root.modelData && root.modelData.icon || "").toLowerCase()
    readonly property string trayIdLower: (root.modelData && root.modelData.id || "").toLowerCase()
    readonly property string trayTitleLower: (root.modelData && root.modelData.tooltipTitle || "").toLowerCase()
    readonly property string trayKey: root.modelData ? TrayService.itemKey(root.modelData) : ""

    implicitWidth: 20
    implicitHeight: 20

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function detectBundledAppId() {
        const haystack = [
            root.modelData.icon || "",
            root.modelData.id || "",
            root.modelData.tooltipTitle || "",
            root.modelData.title || ""
        ].join(" ").toLowerCase()

        if (haystack.indexOf("telegram") >= 0)
            return "telegram"
        if (haystack.indexOf("wechat") >= 0 || haystack.indexOf("weixin") >= 0)
            return "wechat"
        if (haystack.indexOf("discord") >= 0)
            return "discord"
        // Electron QQ：id 常为 chrome_status_icon_*，靠 title/tooltip
        if (haystack.indexOf("linuxqq") >= 0
                || haystack.indexOf("腾讯") >= 0
                || (haystack.indexOf("qq") >= 0 && haystack.indexOf("chrome_status_icon") < 0)
                || (haystack.indexOf("chrome_status_icon") >= 0
                    && (String(root.modelData.tooltipTitle || root.modelData.title || "").toLowerCase().indexOf("qq") >= 0)))
            return "qq"
        return ""
    }

    function bundledIconPath(appId) {
        if (!appId)
            return ""
        // qsl 无独立 assets；复用生产 quickshell 下的社交 SVG
        return "file://" + Quickshell.env("HOME")
            + "/.lian/quickshell/assets/apps/" + appId + ".svg"
    }

    function closeMenu() {
        if (trayMenu.visible)
            trayMenu.visible = false
    }

    function closeOtherMenus() {
        const siblings = root.parent.children
        for (let i = 0; i < siblings.length; i++) {
            const sibling = siblings[i]
            if (sibling === root)
                continue
            if (typeof sibling.closeMenu === "function")
                sibling.closeMenu()
        }
    }

    onClicked: (event) => {
        if (event.button === Qt.LeftButton) {
            modelData.activate()
            trayMenu.visible = false
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
        rootMenuHandle: root.modelData ? root.modelData.menu : null
        trayName: root.modelData
            ? (root.modelData.tooltipTitle || root.modelData.title || root.modelData.id || "Menu")
            : "Menu"
        trayItem: root.modelData
        trayKey: root.trayKey
        anchor.item: root
        anchor.rect.y: (root.mapToItem(null, 0, 0).y > 500)
            ? -trayMenu.implicitHeight - 5
            : root.height + 5
        anchor.rect.x: 0
        onPinToggled: root.pinChanged()
    }

    Image {
        id: iconImg
        anchors.fill: parent
        cache: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.containsMouse ? 1.0 : 0.88
        Behavior on opacity { NumberAnimation { duration: 150 } }

        source: {
            const appId = root.detectBundledAppId()
            if (appId)
                return root.bundledIconPath(appId)
            const raw = root.modelData.icon
            if (!raw)
                return ""
            if (raw.startsWith("/") || raw.startsWith("file://") || raw.startsWith("image://"))
                return raw
            return "image://icon/" + raw
        }

        onStatusChanged: {
            // bundled 缺失时回退系统图标
            if (status === Image.Error) {
                const raw = root.modelData.icon || ""
                if (raw && source.indexOf("/assets/apps/") >= 0) {
                    if (raw.startsWith("/") || raw.startsWith("file://") || raw.startsWith("image://"))
                        source = raw
                    else
                        source = "image://icon/" + raw
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: iconImg.status === Image.Error || !root.modelData.icon
        text: {
            if (root.trayIconLower.indexOf("fcitx") >= 0
                    || root.trayIdLower.indexOf("fcitx") >= 0
                    || root.trayTitleLower.indexOf("fcitx") >= 0)
                return "keyboard"
            if (root.trayIconLower.indexOf("network-wired") >= 0)
                return "lan"
            return "apps"
        }
        color: Color.text
        font.family: Size.fontIcon
        font.pixelSize: Size.fontSize.xl
    }
}
