import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.Modules.DynamicIsland.OverviewContent 

Item {
    id: root
    required property var manager

    visible: !ControlBackend.dndEnabled && manager.hasNotifs

    ListView {
        anchors.fill: parent
        model: root.manager.model
        spacing: Sizes.spacing.m
        clip: true
        interactive: false 

        delegate: Rectangle {
            id: delegateRoot
            width: ListView.view.width
            height: 60
            color: "transparent"

            property string desktopEntry: model.desktopEntry !== undefined ? String(model.desktopEntry) : ""
            property string appName: model.appName !== undefined ? String(model.appName) : ""
            property string summaryText: model.summary !== undefined ? String(model.summary) : ""
            property string bodyText: model.body !== undefined ? String(model.body) : ""

            readonly property bool isIslandEvent: desktopEntry.indexOf("quickshell-island-event") === 0
                                                 || appName.indexOf("IslandEventCenter") === 0

            readonly property string eventSeverity: {
                if (desktopEntry.indexOf("quickshell-island-event.") === 0) {
                    const p = desktopEntry.split(".")
                    if (p.length >= 2)
                        return p[1]
                }

                const t = (summaryText + " " + bodyText).toLowerCase()
                if (t.indexOf("等待确认") >= 0 || t.indexOf("等待表单") >= 0)
                    return "critical"
                if (t.indexOf("失败") >= 0 || t.indexOf("断开") >= 0 || t.indexOf("过高") >= 0 || t.indexOf("偏低") >= 0 || t.indexOf("偏高") >= 0)
                    return "high"
                return "normal"
            }

            readonly property string eventCategory: {
                if (desktopEntry.indexOf("quickshell-island-event.") === 0) {
                    const p = desktopEntry.split(".")
                    if (p.length >= 3)
                        return p[2]
                }

                const t = (summaryText + " " + bodyText).toLowerCase()
                if (t.indexOf("lianclaw") >= 0 || t.indexOf("确认") >= 0 || t.indexOf("表单") >= 0)
                    return "lianclaw"
                if (t.indexOf("录制") >= 0 || t.indexOf("录屏") >= 0 || t.indexOf("gif") >= 0 || t.indexOf("截图") >= 0)
                    return "capture"
                if (t.indexOf("网络") >= 0 || t.indexOf("蓝牙") >= 0)
                    return "connection"
                if (t.indexOf("电池") >= 0 || t.indexOf("磁盘") >= 0)
                    return "power"
                if (t.indexOf("cpu") >= 0 || t.indexOf("gpu") >= 0 || t.indexOf("内存") >= 0 || t.indexOf("温度") >= 0)
                    return "resource"
                return "general"
            }

            readonly property bool isCritical: eventSeverity === "critical"

            readonly property color accentColor: {
                if (!isIslandEvent)
                    return Colorscheme.primary
                if (eventSeverity === "critical")
                    return Colorscheme.error
                if (eventSeverity === "high")
                    return Colorscheme.tertiary
                if (eventCategory === "connection")
                    return Colorscheme.secondary
                if (eventCategory === "lianclaw")
                    return Colorscheme.primary
                if (eventCategory === "power")
                    return Colorscheme.secondary
                return Colorscheme.primary
            }

            readonly property color titleColor: Colorscheme.on_background
            readonly property color bodyColor: Colorscheme.on_surface_variant

            // ============================================================
            // 【核心修复 4】：每条消息自带独立的心脏起搏器，时间一到，精准呼叫后端销毁自己
            // ============================================================
            Timer {
                interval: 5000
                running: true
                onTriggered: root.manager.removeByNotifId(model.notifId)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // 手动点击也走 ID 销毁通道
                onClicked: root.manager.removeByNotifId(model.notifId)
            }

            RowLayout {
                anchors.fill: parent
                anchors.bottomMargin: 4 
                spacing: Sizes.spacing.md

                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    radius: Sizes.rounding.medium
                    color: Colorscheme.background
                    clip: true 

                    property bool isIconName: model.imagePath !== undefined && model.imagePath.startsWith("icon:")
                    property string cleanPath: isIconName ? model.imagePath.substring(5) : (model.imagePath !== undefined ? model.imagePath : "")
                    property string notifSummary: delegateRoot.summaryText
                    property string cleanPathLower: cleanPath.toLowerCase()
                    property string summaryLower: notifSummary.toLowerCase()
                    property bool captureHint: delegateRoot.eventCategory === "capture"
                                               || summaryLower.indexOf("录制") >= 0
                                               || summaryLower.indexOf("录屏") >= 0
                                               || summaryLower.indexOf("gif") >= 0
                                               || summaryLower.indexOf("截图") >= 0
                                               || cleanPathLower.indexOf("camera") >= 0
                                               || cleanPathLower.indexOf("video") >= 0
                                               || cleanPathLower.indexOf("image") >= 0
                    property bool hasThumbnailPreview: !isIconName && (cleanPathLower.endsWith(".png")
                                                || cleanPathLower.endsWith(".jpg")
                                                || cleanPathLower.endsWith(".jpeg")
                                                || cleanPathLower.endsWith(".webp")
                                                || cleanPathLower.endsWith(".gif")
                                                || cleanPathLower.endsWith(".bmp"))
                    property bool forceGlyphIcon: cleanPathLower.indexOf("temperature") >= 0
                                                 || summaryLower.indexOf("温度") >= 0
                                                 || (captureHint && !hasThumbnailPreview)
                    property string fallbackGlyph: {
                        const icon = cleanPathLower
                        const summary = summaryLower

                        if (delegateRoot.eventCategory === "capture") {
                            if (summary.indexOf("gif") >= 0 || icon.endsWith(".gif") || icon.indexOf("image") >= 0)
                                return ""
                            if (summary.indexOf("截图") >= 0 || icon.indexOf("camera-photo") >= 0)
                                return ""
                            return ""
                        }

                        if (icon.indexOf("temperature") >= 0 || summary.indexOf("温度") >= 0)
                            return ""

                        if (delegateRoot.eventCategory === "lianclaw")
                            return ""
                        if (delegateRoot.eventCategory === "connection")
                            return ""
                        if (delegateRoot.eventCategory === "power")
                            return ""
                        if (delegateRoot.eventCategory === "resource"
                            || icon.indexOf("system-monitor") >= 0
                            || summary.indexOf("cpu") >= 0
                            || summary.indexOf("gpu") >= 0
                            || summary.indexOf("内存") >= 0)
                            return ""

                        if (icon.indexOf("battery") >= 0 || summary.indexOf("电池") >= 0)
                            return ""
                        if (icon.indexOf("network") >= 0 || summary.indexOf("网络") >= 0)
                            return ""
                        if (icon.indexOf("bluetooth") >= 0 || summary.indexOf("蓝牙") >= 0)
                            return ""
                        return ""
                    }

                    Image {
                        id: iconImage
                        anchors.fill: parent
                        source: parent.forceGlyphIcon
                                ? ""
                                : (parent.isIconName ? ("image://icon/" + parent.cleanPath) : parent.cleanPath)
                        fillMode: parent.isIconName ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                        anchors.margins: parent.isIconName ? 6 : 0
                        asynchronous: true
                        visible: !parent.forceGlyphIcon
                                 && status !== Image.Error
                                 && status !== Image.Null
                    }

                    Text {
                        id: fallbackIcon
                        anchors.centerIn: parent
                        text: parent.fallbackGlyph
                        visible: parent.forceGlyphIcon
                                 || parent.cleanPath === ""
                                 || iconImage.status === Image.Error
                                 || iconImage.status === Image.Null
                        font.family: Sizes.fontAwesome
                        font.pixelSize: Sizes.font.xl
                        color: delegateRoot.titleColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: Sizes.spacing.xxs
                    Text {
                        text: delegateRoot.summaryText
                        color: delegateRoot.titleColor; font.bold: true; font.pixelSize: Sizes.font.lg
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: delegateRoot.bodyText
                        color: delegateRoot.bodyColor; font.pixelSize: Sizes.font.sm
                        Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2
                    }
                }
                
                Text {
                    text: "×"; color: Qt.alpha(delegateRoot.titleColor, 0.56); font.pixelSize: Sizes.font.xxl
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter 
                height: 2
                radius: Sizes.rounding.hairline
                color: delegateRoot.isIslandEvent ? delegateRoot.accentColor : Colorscheme.primary
                
                NumberAnimation on width {
                    from: delegateRoot.width - 20 
                    to: 0
                    duration: 5000 
                }
            }
        }
    }
}
