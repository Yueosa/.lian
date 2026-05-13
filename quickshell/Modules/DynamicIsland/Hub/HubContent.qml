import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config

import qs.Modules.DynamicIsland.OverviewContent
import qs.Modules.DynamicIsland.Media
import qs.Modules.DynamicIsland.WallpaperContent
import qs.Modules.DynamicIsland.WeatherContent
import qs.Modules.DynamicIsland.SwitcherContent

FocusScope {
    id: root
    signal closeRequested()
    
    property var player: null
    property int currentIndex: 0
    
    focus: visible
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            root.currentIndex = (root.currentIndex + 1) % 5
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backtab) {
            root.currentIndex = (root.currentIndex + 4) % 5
            event.accepted = true
        }
    }

    onVisibleChanged: {
        if (visible)
            root.forceActiveFocus()
    }
    
    // 5 Tab 布局：Overview / Media / Wallpaper / Weather / Switcher
    implicitWidth: currentIndex === 0 ? Sizes.island.overviewWidth : (currentIndex === 4 ? 900 : (currentIndex === 2 ? 860 : 760))
    Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    
    implicitHeight: Sizes.island.hubTabBarHeight + Sizes.island.hubContentGap + (
        currentIndex === 0 ? Sizes.island.overviewHeight : 
        currentIndex === 1 ? 480 : 
        currentIndex === 2 ? 540 :
        currentIndex === 3 ? 540 :
        540
    )
    Behavior on implicitHeight { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    RowLayout {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Sizes.island.hubTabBarHeight
        anchors.margins: 10
        spacing: Sizes.island.hubTabSpacing

        component TabBtn : Item {
            property string icon: ""
            property string title: ""
            property int index: 0
            property bool active: root.currentIndex === index
            
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.centerIn: parent
                spacing: Sizes.spacing.s
                Text {
                    text: parent.parent.icon
                    font.family: Sizes.fontAwesome
                    font.pixelSize: Sizes.font.title
                    color: parent.parent.active ? Colorscheme.on_background : Colorscheme.on_surface_variant
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    text: parent.parent.title
                    font.pixelSize: Sizes.font.md
                    font.bold: parent.parent.active
                    color: parent.parent.active ? Colorscheme.on_background : Colorscheme.on_surface_variant
                    anchors.horizontalCenter: parent.horizontalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.active ? Sizes.island.hubTabIndicatorWidth : 0
                height: Sizes.island.hubTabIndicatorHeight
                radius: Sizes.island.hubTabIndicatorHeight / 2
                color: Colorscheme.on_background
                opacity: parent.active ? 1.0 : 0.0
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.currentIndex = parent.index
            }
        }

        TabBtn { icon: ""; title: "Overview"; index: 0 }
        TabBtn { icon: ""; title: "Media"; index: 1 }
        TabBtn { icon: ""; title: "Wallpaper"; index: 2 }
        TabBtn { icon: ""; title: "Weather"; index: 3 }
        TabBtn { icon: "\uf2d2"; title: "Switcher"; index: 4 }
    }

    Item {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Sizes.island.hubContentGap

        OverviewContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 0
            enabled: root.currentIndex === 0
            z: enabled ? 1 : 0
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
        }

        Media {
            player: root.player
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 1
            enabled: root.currentIndex === 1
            z: enabled ? 1 : 0
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        WeatherContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 3
            enabled: root.currentIndex === 3
            z: enabled ? 1 : 0
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        WallpaperContent {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentIndex === 2
            enabled: root.currentIndex === 2
            z: enabled ? 1 : 0
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
        }

        SwitcherContent {
            anchors.fill: parent
            visible: root.currentIndex === 4
            enabled: root.currentIndex === 4
            z: enabled ? 1 : 0
            opacity: enabled ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            onCloseRequested: root.closeRequested()
        }
    }}