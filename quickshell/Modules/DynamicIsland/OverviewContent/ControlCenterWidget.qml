import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.Widget.common
import qs.Modules.DynamicIsland.OverviewContent

Item {
    id: root
    readonly property var chargingProfiles: ["high_capacity", "balanced", "stationary"]
    readonly property var chargingProfileIcons: ["", "", ""]

    // ============================================================
    // 【组件库】
    // ============================================================
    component MiniCircleBtn : Item {
        property string icon: ""
        property bool active: false
        property color activeColor: Colorscheme.primary
        property color inactiveColor: Colorscheme.surface_container_highest
        property color iconActiveColor: Colorscheme.on_primary
        property color iconInactiveColor: Colorscheme.on_surface
        
        signal clicked()

        Layout.preferredWidth: 48
        Layout.preferredHeight: 48

        Rectangle {
            anchors.fill: parent
            radius: width / 2 
            color: active ? activeColor : inactiveColor
            Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
            scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

            Text { 
                anchors.centerIn: parent
                text: icon
                font.family: Sizes.fontAwesome
                font.pixelSize: Sizes.font.xl
                color: active ? iconActiveColor : iconInactiveColor 
            }

            MouseArea { 
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor 
                onClicked: parent.parent.clicked() 
            }
        }
    }

    component ShapeShiftTile : Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        
        signal clicked()

        Layout.preferredWidth: 112
        Layout.preferredHeight: 48
        
        radius: active ? 12 : height / 2
        Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
        
        color: active ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.15) : Colorscheme.surface_container_highest
        Behavior on color { ColorAnimation { duration: 250 } }
        
        scale: tileArea.pressed ? 0.94 : (tileArea.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Rectangle {
            id: innerBlock
            width: 32
            height: 32
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            radius: tile.active ? 10 : width / 2
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
            color: tile.active ? Colorscheme.primary : Colorscheme.surface_variant
            Behavior on color { ColorAnimation { duration: 250 } }
            
            Text { 
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Colorscheme.on_primary : Colorscheme.on_surface
                font.family: Sizes.fontAwesome
                font.pixelSize: Sizes.font.lg 
            }
        }

        ColumnLayout {
            anchors.left: innerBlock.right
            anchors.leftMargin: 10
            anchors.right: parent.right      // 【新增】：强行规定右侧边界
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text { 
                text: tile.title
                font.pixelSize: Sizes.font.md
                font.bold: true
                color: Colorscheme.on_surface 
                Layout.fillWidth: true       // 【新增】：填满剩余空间
                elide: Text.ElideRight       // 【新增】：超出自动变成省略号
            }
            Text { 
                text: tile.subtitle
                font.pixelSize: Sizes.font.xs
                opacity: 0.8
                color: Colorscheme.on_surface
                visible: tile.subtitle !== "" 
                Layout.fillWidth: true       // 【新增】：填满剩余空间
                elide: Text.ElideRight       // 【新增】：超出自动变成省略号
            }
        }

        MouseArea { 
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked() 
        }
    }

    component CornerBtn : Rectangle {
        property string icon: ""
        property color bgColor: "transparent"
        property color fgColor: "white"

        signal clicked()

        width: 48
        height: 48
        radius: Sizes.rounding.chip 
        color: bgColor
        
        scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: icon
            color: fgColor 
            font.family: Sizes.fontAwesome
            font.pixelSize: Sizes.font.xxl
        }

        MouseArea { 
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor 
            onClicked: parent.clicked()
        }
    }


    // ============================================================
    // 【网格布局】
    // ============================================================
    // ============================================================
    // 【主布局】
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: Sizes.spacing.l

        // ── Row 0：Wi-Fi + 蓝牙 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.sm

            ShapeShiftTile {
                Layout.fillWidth: true
                icon: ""
                title: "Wi-Fi"
                active: ControlBackend.wifiEnabled
                subtitle: ControlBackend.wifiEnabled ? "已连接" : "已断开"
                onClicked: ControlBackend.toggleWifi()
            }

            ShapeShiftTile {
                Layout.fillWidth: true
                icon: ""
                title: "蓝牙"
                active: ControlBackend.bluetoothEnabled
                subtitle: !ControlBackend.bluetoothEnabled ? "已关闭" : (ControlBackend.bluetoothConnected ? "已连接" : "已开启")
                onClicked: ControlBackend.toggleBluetooth()
            }
        }

        // ── Row 1：充电策略 + 勿扰 + 重载 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.sm

            Repeater {
                model: root.chargingProfiles

                MiniCircleBtn {
                    required property string modelData
                    required property int index
                    icon: root.chargingProfileIcons[index]
                    active: ControlBackend.chargingProfile === modelData
                    activeColor: Colorscheme.tertiary
                    iconActiveColor: Colorscheme.on_tertiary
                    onClicked: ControlBackend.setChargingProfile(modelData)
                }
            }

            MiniCircleBtn {
                icon: ""
                active: ControlBackend.dndEnabled
                onClicked: ControlBackend.toggleDnd()
            }

            MiniCircleBtn {
                icon: ""
                onClicked: Quickshell.execDetached(["qs", "reload"])
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }

        // ── 底部：快捷功能栏 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.sm

            CornerBtn {
                icon: ""
                bgColor: WidgetState.leftSidebarOpen ? Qt.alpha(Colorscheme.primary, 0.15) : Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: WidgetState.leftSidebarOpen ? Colorscheme.primary : Colorscheme.on_surface
                onClicked: WidgetState.leftSidebarOpen = !WidgetState.leftSidebarOpen
            }

            CornerBtn {
                icon: ""
                bgColor: WidgetState.notifOpen ? Qt.alpha(Colorscheme.primary, 0.15) : Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: WidgetState.notifOpen ? Colorscheme.primary : Colorscheme.on_surface
                onClicked: WidgetState.notifOpen = !WidgetState.notifOpen
            }

            CornerBtn {
                icon: ""
                bgColor: Qt.alpha(Colorscheme.on_surface, 0.08)
                fgColor: Colorscheme.on_surface
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "clipboard", "toggle"])
            }

            Item { Layout.fillWidth: true }

            CornerBtn {
                icon: ""
                bgColor: Qt.alpha(Colorscheme.error, 0.12)
                fgColor: Colorscheme.error
                onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/wlogout/scripts/logoutlaunch.sh"])
            }
        }
    }
}
