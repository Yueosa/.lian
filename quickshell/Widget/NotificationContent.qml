import QtQuick
import QtQuick.Layouts
import qs.config
import qs.Widget.common
import qs.Modules.DynamicIsland.OverviewContent
import Clavis.Notif
import "./notification" 

Item {
    id: root
    Theme { id: theme }

    readonly property int activeViewHeight: currentViewItem ? currentViewItem.totalHeight : 80
    readonly property int totalHeight: activeViewHeight + 40 + theme.padding * 2
    
    property var allMessages: NotificationStore.allMessages()
    property bool hasMessages: allMessages.length > 0

    Connections { 
        target: NotificationStore;
        function onDataChanged() { 
            root.allMessages = NotificationStore.allMessages();
            mainView.update(); detailView.update();
            allView.update(); 
        } 
    }
    
    property var currentViewItem: stackLayout.children[stackLayout.currentIndex]

    Item {
        id: headerArea
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.topMargin: theme.padding; anchors.leftMargin: theme.padding; anchors.rightMargin: theme.padding
        height: 32

        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: WidgetState.notifCurrentView === "detail" ? "应用详情" : "通知中心"
            font.bold: true; font.pixelSize: Sizes.font.xl; color: theme.text
        }

        RowLayout {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: Sizes.spacing.sm

            // ============================================================
            // 0. 【新增】：返回主面板按钮 (仅在非主页时显示)
            // ============================================================
            Rectangle {
                width: 32; height: 32; radius: Sizes.rounding.large
                color: backHover.containsMouse ? Colorscheme.surface_container_high : "transparent"
                // 当不在 main 视图，或者处于 all 长列表模式时，显示返回按钮
                visible: WidgetState.notifCurrentView !== "main" || WidgetState.notifDisplayMode !== "compact"

                Text {
                    anchors.centerIn: parent
                    text: "\uf060" // 箭头向左的返回图标
                    font.family: "Font Awesome 6 Free Solid"; font.pixelSize: Sizes.font.lg; color: theme.text
                }

                MouseArea {
                    id: backHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // 强制重置回最纯粹的初始主面板状态
                        WidgetState.notifCurrentView = "main";
                        WidgetState.notifDisplayMode = "compact";
                    }
                }
            }

            // 1. 免打扰按钮
            Rectangle {
                width: 32; height: 32; radius: Sizes.rounding.large
                color: dndHover.containsMouse
                    ? (ControlBackend.dndEnabled ? Qt.rgba(1,0.5,0,0.2) : Colorscheme.surface_container_high)
                    : (ControlBackend.dndEnabled ? Qt.rgba(1,0.5,0,0.12) : "transparent")

                Text {
                    anchors.centerIn: parent
                    text: ControlBackend.dndEnabled ? "\uf1f6" : "\uf0f3"
                    font.family: "Font Awesome 6 Free Solid"; font.pixelSize: Sizes.font.lg
                    color: ControlBackend.dndEnabled ? Colorscheme.secondary_container : theme.text
                }

                MouseArea {
                    id: dndHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: ControlBackend.toggleDnd()
                }
            }

            // 2. 清空通知按钮
            Rectangle {
                width: 32; height: 32; radius: Sizes.rounding.large
                color: trashHover.containsMouse && root.hasMessages ? Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.15) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf1f8" 
                    font.family: "Font Awesome 6 Free Solid"; font.pixelSize: Sizes.font.lg
                    color: root.hasMessages ? theme.error : theme.subtext
                    opacity: root.hasMessages ? 1.0 : 0.4
                }

                MouseArea {
                    id: trashHover
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: root.hasMessages ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.hasMessages) NotificationStore.clearAll();
                    }
                }
            }

            // 2. 视图切换按钮
            Rectangle {
                width: 32; height: 32; radius: Sizes.rounding.large
                color: modeHover.containsMouse ? Colorscheme.surface_container_high : "transparent"
                visible: WidgetState.notifCurrentView !== "detail" 

                Text {
                    anchors.centerIn: parent
                    text: WidgetState.notifDisplayMode === "compact" ? "\uf0ca" : "\uf009" 
                    font.family: "Font Awesome 6 Free Solid"; font.pixelSize: Sizes.font.lg; color: theme.text
                }

                MouseArea {
                    id: modeHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { WidgetState.notifDisplayMode = WidgetState.notifDisplayMode === "compact" ? "all" : "compact"; }
                }
            }

            // 3. 关闭 (X) 按钮
            Rectangle {
                width: 32; height: 32; radius: Sizes.rounding.large
                color: closeHover.containsMouse ? Colorscheme.surface_container_high : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "\uf00d" 
                    font.family: "Font Awesome 6 Free Solid"
                    font.pixelSize: Sizes.font.xl; color: theme.text
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WidgetState.notifOpen = false;
                        WidgetState.notifPinned = false; 
                    }
                }
            }
        }
    }

    StackLayout {
        id: stackLayout
        anchors.top: headerArea.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: theme.padding
        anchors.topMargin: 12 
        
        currentIndex: {
            if (WidgetState.notifCurrentView === "detail") return 1;
            if (WidgetState.notifDisplayMode === "all") return 2;    
            return 0;                                                
        }

        NotifMainView { id: mainView; Layout.fillWidth: true; Layout.fillHeight: true }
        NotifDetailView { id: detailView; Layout.fillWidth: true; Layout.fillHeight: true; appId: WidgetState.notifDetailAppId }
        NotifAllView { id: allView; Layout.fillWidth: true; Layout.fillHeight: true } 
    }
}
