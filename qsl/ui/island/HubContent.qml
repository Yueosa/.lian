// HubContent — 三级岛 Tab 壳
// 单 Loader：仅当前页实例化；关 Hub 由外层卸掉整个 HubContent
//
// 性能：无五页常驻；Tab 切换销毁旧页

import QtQuick
import QtQuick.Layouts
import qs.data.state

FocusScope {
    id: root

    signal closeRequested()

    // 与 Island 单例双向同步（避免壳层再套一层 Connections）
    property int currentIndex: Island.hubTabIndex

    onCurrentIndexChanged: {
        if (Island.hubTabIndex !== currentIndex)
            Island.hubTabIndex = currentIndex
    }

    Connections {
        target: Island
        function onHubTabIndexChanged() {
            if (root.currentIndex !== Island.hubTabIndex)
                root.currentIndex = Island.hubTabIndex
        }
    }

    focus: visible

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ControlModifier)) {
            root.currentIndex = (root.currentIndex + 1) % 5
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backtab) {
            root.currentIndex = (root.currentIndex + 4) % 5
            event.accepted = true
        }
    }

    // Keys 依赖焦点；Shortcut 不依赖，和壳层 Esc 双保险
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.closeRequested()
    }

    onVisibleChanged: {
        if (visible)
            forceActiveFocus()
    }

    readonly property int contentW: {
        switch (currentIndex) {
        case 0: return Size.island.overviewWidth
        case 1: return Size.island.mediaWidth
        case 2: return Size.island.wallpaperWidth
        case 3: return Size.island.weatherWidth
        default: return Size.island.switcherWidth
        }
    }

    readonly property int contentH: {
        switch (currentIndex) {
        case 0: return Size.island.overviewHeight
        case 1: return Size.island.mediaHeight
        case 2: return Size.island.wallpaperHeight
        case 3: return Size.island.weatherHeight
        default: return Size.island.switcherHeight
        }
    }

    implicitWidth: contentW
    implicitHeight: Size.island.hubTabBarHeight + Size.island.hubContentGap + contentH

    Behavior on implicitWidth {
        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
    }

    readonly property var tabMeta: [
        { icon: "\uf009", title: "Overview" },
        { icon: "\uf001", title: "Media" },
        { icon: "\uf03e", title: "Wallpaper" },
        { icon: "\uf185", title: "Weather" },
        { icon: "\uf2d2", title: "Switcher" }
    ]

    RowLayout {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Size.island.hubTabBarHeight
        anchors.margins: 10
        spacing: Size.island.hubTabSpacing

        Repeater {
            model: root.tabMeta

            Item {
                required property var modelData
                required property int index
                readonly property bool active: root.currentIndex === index

                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.centerIn: parent
                    spacing: Size.spacing.xs

                    Text {
                        text: modelData.icon
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.title
                        color: active ? Color.textOnBackground : Color.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        text: modelData.title
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        font.bold: active
                        color: active ? Color.textOnBackground : Color.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: active ? Size.island.hubTabIndicatorWidth : 0
                    height: Size.island.hubTabIndicatorHeight
                    radius: Size.island.hubTabIndicatorHeight / 2
                    color: Color.textOnBackground
                    opacity: active ? 1 : 0
                    Behavior on width {
                        NumberAnimation { duration: 300; easing.type: Easing.OutBack }
                    }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentIndex = index
                }
            }
        }
    }

    Loader {
        id: pageLoader
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Size.island.hubContentGap
        anchors.margins: 12
        active: true
        sourceComponent: {
            switch (root.currentIndex) {
            case 0: return overviewComp
            case 1: return mediaComp
            case 2: return wallpaperComp
            case 3: return weatherComp
            default: return switcherComp
            }
        }
    }

    Component {
        id: overviewComp
        OverviewPage {}
    }
    Component {
        id: mediaComp
        HubPlaceholder { title: "Media"; hint: "待从旧 qs 搬迁" }
    }
    Component {
        id: wallpaperComp
        HubPlaceholder { title: "Wallpaper"; hint: "待从旧 qs 搬迁" }
    }
    Component {
        id: weatherComp
        HubPlaceholder { title: "Weather"; hint: "待从旧 qs 搬迁" }
    }
    Component {
        id: switcherComp
        HubPlaceholder { title: "Switcher"; hint: "待从旧 qs 搬迁" }
    }
}
