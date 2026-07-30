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

    // tab 上下/左右各 10，page 左右底 12；高度必须计入，否则 body.clip 会裁顶/底
    readonly property int hubChromeTop: 10
    readonly property int hubChromeBottom: 12
    readonly property int hubChromeSide: 12

    implicitWidth: contentW
    implicitHeight: hubChromeTop + Size.island.hubTabBarHeight
        + Size.island.hubContentGap + contentH + hubChromeBottom

    // Loader centerIn 时要把隐式尺寸落到真实宽高，否则子页 anchors.fill 会按 0 算
    width: implicitWidth
    height: implicitHeight

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
        anchors.topMargin: root.hubChromeTop
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: Size.island.hubTabBarHeight
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
        anchors.leftMargin: root.hubChromeSide
        anchors.rightMargin: root.hubChromeSide
        anchors.bottomMargin: root.hubChromeBottom
        active: true
        // 让子页能抢到键盘（Enter/方向键）；否则焦点停在 Hub FocusScope
        focus: true
        sourceComponent: {
            switch (root.currentIndex) {
            case 0: return overviewComp
            case 1: return mediaComp
            case 2: return wallpaperComp
            case 3: return weatherComp
            default: return switcherComp
            }
        }
        onLoaded: {
            if (item && typeof item.forceActiveFocus === "function")
                Qt.callLater(() => {
                    if (pageLoader.item)
                        pageLoader.item.forceActiveFocus()
                })
        }
    }

    Component {
        id: overviewComp
        OverviewPage {}
    }
    Component {
        id: mediaComp
        MediaPage {}
    }
    Component {
        id: wallpaperComp
        WallpaperPage {}
    }
    Component {
        id: weatherComp
        WeatherPage {}
    }
    Component {
        id: switcherComp
        SwitcherPage {}
    }
}
