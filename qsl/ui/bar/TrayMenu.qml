// TrayMenu — 托盘右键菜单（无 MultiEffect；保留 submenu hydrator）

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state

PopupWindow {
    id: root

    property var rootMenuHandle: null
    property string trayName: ""

    function resolveMenuIconSource(iconValue) {
        const raw = iconValue || ""
        const lower = raw.toLowerCase()
        if (!raw)
            return ""
        if (raw.startsWith("/") || raw.startsWith("file://") || raw.startsWith("image://"))
            return raw
        if (lower === "input-keyboard" || lower === "input-keyboard-symbolic")
            return ""
        if (lower === "view-refresh" || lower === "application-exit")
            return ""
        return "image://icon/" + raw
    }

    function menuIconGlyph(iconValue) {
        const lower = (iconValue || "").toLowerCase()
        if (lower === "input-keyboard" || lower === "input-keyboard-symbolic")
            return "keyboard"
        if (lower === "view-refresh")
            return "refresh"
        if (lower === "application-exit")
            return "logout"
        return ""
    }

    implicitWidth: 240
    implicitHeight: Math.min(600, mainLayout.implicitHeight + 20)
    color: "transparent"

    onVisibleChanged: {
        if (visible)
            menuStack.clear()
    }

    ListModel { id: menuStack }

    property var currentSubMenuHandle: {
        if (menuStack.count === 0)
            return null
        return menuStack.get(menuStack.count - 1).handle
    }

    QsMenuOpener {
        id: rootOpener
        menu: root.rootMenuHandle
    }

    QsMenuOpener {
        id: subOpener
        menu: root.currentSubMenuHandle
    }

    QsMenuAnchor {
        id: hydrator
        anchor.window: root
        anchor.item: mainLayout
        anchor.rect.x: root.width / 2
        anchor.rect.y: root.height / 2
        anchor.rect.width: 1
        anchor.rect.height: 1
    }

    function navigateToSubmenu(menuHandle, menuText) {
        if (!menuHandle)
            return
        menuStack.append({ "handle": menuHandle, "title": menuText })
        try {
            if (typeof menuHandle.aboutToShow === "function")
                menuHandle.aboutToShow()
            if (typeof menuHandle.updateLayout === "function")
                menuHandle.updateLayout()
            hydrator.menu = menuHandle
            hydrator.open()
            Qt.callLater(() => {
                if (hydrator.menu === menuHandle)
                    hydrator.close()
            })
        } catch (e) {
            console.warn("TrayMenu hydrator:", e)
        }
    }

    function navigateBack() {
        if (menuStack.count > 0)
            menuStack.remove(menuStack.count - 1, 1)
    }

    Rectangle {
        anchors.fill: parent
        color: Color.surfaceHigh
        radius: Size.rounding.md
        border.width: 1
        border.color: Color.outlineVariant
        clip: true

        ColumnLayout {
            id: mainLayout
            width: parent.width
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "transparent"

                Text {
                    text: (menuStack.count === 0)
                        ? (root.trayName || "Menu")
                        : menuStack.get(menuStack.count - 1).title
                    anchors.centerIn: parent
                    font.bold: true
                    color: Color.primary
                    font.pixelSize: Size.fontSize.md
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: menuStack.count > 0
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: Size.rounding.sm
                    color: backMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.15)
                        : "transparent"

                    Text {
                        text: "arrow_back"
                        anchors.centerIn: parent
                        color: Color.text
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.lg
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateBack()
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Color.primary
                    opacity: 0.2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: Size.spacing.xs

                property var currentModel: (menuStack.count === 0)
                    ? (rootOpener.children ? rootOpener.children.values : [])
                    : (subOpener.children ? subOpener.children.values : [])

                Text {
                    visible: (!parent.currentModel || parent.currentModel.length === 0)
                    text: (menuStack.count > 0) ? "Loading..." : "No Items"
                    color: Color.secondary
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.margins: 10
                }

                Repeater {
                    model: parent.currentModel

                    delegate: Rectangle {
                        id: menuItem
                        required property var modelData
                        property bool isSeparator: (modelData.isSeparator === true || modelData.text === "")
                        property bool hasSubMenu: (modelData.hasChildren === true)
                        property var effectiveHandle: modelData.menu ? modelData.menu : modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: isSeparator ? 9 : 36
                        radius: Size.rounding.sm
                        color: (itemMa.containsMouse && !isSeparator)
                            ? Color.withAlpha(Color.primary, 0.15)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Rectangle {
                            visible: menuItem.isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 20
                            height: 1
                            color: Color.outlineVariant
                            opacity: 0.5
                        }

                        RowLayout {
                            visible: !menuItem.isSeparator
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: Size.spacing.md

                            Item {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                visible: (modelData.icon || "") !== ""
                                property string glyph: root.menuIconGlyph(modelData.icon)

                                Image {
                                    id: iconRaw
                                    anchors.fill: parent
                                    source: root.resolveMenuIconSource(modelData.icon)
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready && parent.glyph === ""
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.glyph !== "" || iconRaw.status === Image.Error
                                    text: parent.glyph !== "" ? parent.glyph : "apps"
                                    font.family: Size.fontIcon
                                    font.pixelSize: Size.fontSize.md
                                    color: itemMa.containsMouse ? Color.primary : Color.secondary
                                }
                            }

                            Text {
                                visible: modelData.toggleState === 1
                                text: "check"
                                font.family: Size.fontIcon
                                color: Color.primary
                                font.pixelSize: Size.fontSize.md
                            }

                            Text {
                                text: modelData.text || ""
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: {
                                    if (modelData.enabled === false)
                                        return Color.outline
                                    if (itemMa.containsMouse)
                                        return Color.primary
                                    return Color.text
                                }
                                font.pixelSize: Size.fontSize.md
                                font.weight: itemMa.containsMouse ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                visible: menuItem.hasSubMenu
                                text: "chevron_right"
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.lg
                                color: itemMa.containsMouse ? Color.primary : Color.tertiary
                            }
                        }

                        MouseArea {
                            id: itemMa
                            visible: !menuItem.isSeparator
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: modelData.enabled !== false
                            onClicked: {
                                if (menuItem.hasSubMenu) {
                                    root.navigateToSubmenu(menuItem.effectiveHandle, modelData.text)
                                } else {
                                    modelData.triggered()
                                    root.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
