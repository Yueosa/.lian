import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.config
import qs.Widget.common
import qs.Modules.DynamicIsland.OverviewContent
import Clavis.Notif
import "../notification"

Item {
    id: root
    Theme { id: theme }
    property real uiScale: 1.0

    property bool isForeground: WidgetState.leftSidebarOpen && WidgetState.leftSidebarView === "info"

    Flickable {
        id: scrollArea
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 2
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        function wheelPage(angleDeltaY) {
            if (angleDeltaY === 0) return;
            const direction = angleDeltaY > 0 ? -1 : 1;
            const target = scrollArea.contentY + direction * Math.max(120, scrollArea.height * 0.6);
            scrollArea.contentY = Math.max(0, Math.min(target, Math.max(0, scrollArea.contentHeight - scrollArea.height)));
        }

        Behavior on contentY {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                scrollArea.wheelPage(event.angleDelta.y);
                event.accepted = true;
            }
        }

        ColumnLayout {
            id: contentColumn
            width: scrollArea.width - 40
            x: 20
            y: 18
            spacing: Sizes.spacing.md

            // ── 个人名片 ────────────────────────────────────────

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(new Date(), "dddd")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(45 * root.uiScale)
                font.bold: true
                color: theme.error
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(new Date(), "dd MMMM yyyy")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(22 * root.uiScale)
                font.bold: true
                color: theme.subtext
                Layout.topMargin: -8
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 15
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: Math.round(180 * root.uiScale)
                height: Math.round(180 * root.uiScale)

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.lian/hypr/pln_avatar.jpg"
                    sourceSize: Qt.size(360, 360)
                    fillMode: Image.PreserveAspectCrop
                    mipmap: true
                    cache: false
                    visible: false
                }

                Rectangle {
                    id: mask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    color: "black"
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: mask
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Sizes.spacing.xsm
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER") || "lian"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(36 * root.uiScale)
                font.bold: true
                color: theme.error
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "@" + (Quickshell.env("USER") || "lian")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(20 * root.uiScale)
                color: theme.subtext
                Layout.topMargin: -6
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }

            // ── 通知中心 ─────────────────────────────────────────

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(theme.subtext.r, theme.subtext.g, theme.subtext.b, 0.2)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Sizes.spacing.xs

                Text {
                    text: WidgetState.notifCurrentView === "detail" ? "应用通知" : "通知中心"
                    font.family: "LXGW WenKai GB"
                    font.pixelSize: Math.round(16 * root.uiScale)
                    font.bold: true
                    color: theme.text
                    Layout.fillWidth: true
                }

                // 返回按钮（从 detail 或 all 视图返回）
                Rectangle {
                    width: 28; height: 28; radius: Sizes.rounding.chip
                    color: backNotifMa.containsMouse ? Colorscheme.surface_container_high : "transparent"
                    visible: WidgetState.notifCurrentView !== "main" || WidgetState.notifDisplayMode !== "compact"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "arrow_back"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Sizes.font.xl
                        color: theme.text
                    }
                    MouseArea {
                        id: backNotifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            WidgetState.notifCurrentView = "main";
                            WidgetState.notifDisplayMode = "compact";
                        }
                    }
                }

                // 免打扰按钮
                Rectangle {
                    width: 28; height: 28; radius: Sizes.rounding.chip
                    color: dndNotifMa.containsMouse
                        ? (ControlBackend.dndEnabled ? Qt.rgba(1,0.5,0,0.25) : Colorscheme.surface_container_high)
                        : (ControlBackend.dndEnabled ? Qt.rgba(1,0.5,0,0.15) : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: ControlBackend.dndEnabled ? "notifications_off" : "notifications"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Sizes.font.xl
                        color: ControlBackend.dndEnabled ? Colorscheme.secondary_container : theme.text
                    }
                    MouseArea {
                        id: dndNotifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ControlBackend.toggleDnd()
                    }
                }

                // 折叠/总览切换按钮
                Rectangle {
                    width: 28; height: 28; radius: Sizes.rounding.chip
                    color: modeNotifMa.containsMouse ? Colorscheme.surface_container_high : "transparent"
                    visible: WidgetState.notifCurrentView !== "detail"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: WidgetState.notifDisplayMode === "compact" ? "view_list" : "grid_view"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Sizes.font.xl
                        color: theme.text
                    }
                    MouseArea {
                        id: modeNotifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WidgetState.notifDisplayMode = (WidgetState.notifDisplayMode === "compact" ? "all" : "compact")
                    }
                }

                // 清空按钮
                Rectangle {
                    width: 28; height: 28; radius: Sizes.rounding.chip
                    color: clearNotifMa.containsMouse ? Colorscheme.surface_container_high : "transparent"
                    visible: WidgetState.notifCurrentView === "main"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "delete_sweep"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Sizes.font.xl
                        color: theme.subtext
                    }
                    MouseArea {
                        id: clearNotifMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationStore.clearAll()
                    }
                }
            }

            NotifMainView {
                id: notifMainView
                Layout.fillWidth: true
                Layout.preferredHeight: totalHeight
                visible: WidgetState.notifCurrentView === "main" && WidgetState.notifDisplayMode === "compact"
            }

            NotifAllView {
                id: notifAllView
                Layout.fillWidth: true
                Layout.preferredHeight: totalHeight
                visible: WidgetState.notifCurrentView === "main" && WidgetState.notifDisplayMode === "all"
                Connections {
                    target: WidgetState
                    function onNotifDataChanged() { notifAllView.update() }
                }
            }

            NotifDetailView {
                id: notifDetailView
                Layout.fillWidth: true
                Layout.preferredHeight: totalHeight
                appId: WidgetState.notifDetailAppId
                visible: WidgetState.notifCurrentView === "detail"
                onVisibleChanged: if (visible) update()
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }
        }
    }
}
