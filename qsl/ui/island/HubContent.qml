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
    // 真正喂给 Loader 的下标。currentIndex 可以先变（岛尺寸立刻跟上），
    // shownIndex 等旧页淡完再换，这样天气页的 Canvas 先隐掉再卸
    property int shownIndex: Island.hubTabIndex
    property int fadePhase: 0

    onCurrentIndexChanged: {
        if (Island.hubTabIndex !== currentIndex)
            Island.hubTabIndex = currentIndex
        if (currentIndex === shownIndex)
            return
        if (fadePhase === 1)
            return
        if (pageLoader.item)
            startPageOut()
        else
            shownIndex = currentIndex
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
    implicitHeight: Size.island.hubChromeH + contentH

    // Loader 定位时要把隐式尺寸落到真实宽高，否则子页 anchors.fill 会按 0 算
    width: implicitWidth
    height: implicitHeight

    // 这里**不要**加 Behavior on implicitWidth/implicitHeight。
    //
    // 加了会变成两层动画串联：body 用 SpatialFast(400ms) 追一个自己也在
    // 用 Spatial(500ms) 移动的目标，落定要 700ms 以上，而且两条都带过冲，
    // 观感是橡皮筋。更贵的是——尺寸每帧都在动，页内容就每帧全量重排一次
    // （天气页那条 Canvas 曲线每帧重画），天气页切出去卡就是卡在这儿。
    //
    // 现在让隐式尺寸一步到位：页只重排一次，body.clip 负责把多出来的部分
    // 裁掉，动的只有裁剪框。子页配合 IslandShell 里 hubLoader 的顶部对齐，
    // tab 条原地不动，只有岛底边在收放。

    function startPageOut() {
        fadePhase = 1
        pageFade.stop()
        pageFade.easing.bezierCurve = Size.anim.curveAccel
        pageFade.duration = Size.anim.durFx
        pageFade.from = pageLoader.opacity
        pageFade.to = 0
        pageFade.start()
    }

    function startPageIn() {
        fadePhase = 2
        pageFade.stop()
        pageFade.easing.bezierCurve = Size.anim.curveDecel
        pageFade.duration = Size.anim.durFxSlow
        pageFade.from = 0
        pageFade.to = 1
        pageFade.start()
    }

    NumberAnimation {
        id: pageFade
        target: pageLoader
        property: "opacity"
        duration: Size.anim.durFx
        easing.type: Easing.Bezier
        easing.bezierCurve: Size.anim.curveAccel
        onStopped: {
            if (root.fadePhase === 1) {
                root.shownIndex = root.currentIndex
                pageLoader.opacity = 0
                // 异步孵化：新页走 onLoaded。不要在这里 enter——
                // sourceComponent 还没换完的话 item 仍是旧页
            } else if (root.fadePhase === 2) {
                root.fadePhase = 0
            }
        }
    }

    function enterShownPage() {
        if (pageLoader.item && typeof pageLoader.item.playEnter === "function")
            pageLoader.item.playEnter()
        startPageIn()
        if (pageLoader.item && typeof pageLoader.item.forceActiveFocus === "function")
            Qt.callLater(() => {
                if (pageLoader.item)
                    pageLoader.item.forceActiveFocus()
            })
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
                        color: active ? Color.backgroundText : Color.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { CAnim {} }
                    }
                    Text {
                        text: modelData.title
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        font.bold: active
                        color: active ? Color.backgroundText : Color.textMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { CAnim {} }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: active ? Size.island.hubTabIndicatorWidth : 0
                    height: Size.island.hubTabIndicatorHeight
                    radius: Size.island.hubTabIndicatorHeight / 2
                    color: Color.backgroundText
                    opacity: active ? 1 : 0
                    Behavior on width {
                        Anim {}
                    }
                    Behavior on opacity { Anim { type: Anim.Effects } }
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
        // 异步孵化：同步建 OverviewPage 要一次性铺 3 个月面板 ×42 格 ×4 个
        // item，实测就是切 Tab 那一下的掉帧。异步是分帧建，没有单次长阻塞。
        // 岛的目标尺寸只看 Size 令牌、不看 item，所以先空着不影响 morph
        asynchronous: true
        // 让子页能抢到键盘（Enter/方向键）；否则焦点停在 Hub FocusScope
        focus: true
        sourceComponent: {
            switch (root.shownIndex) {
            case 0: return overviewComp
            case 1: return mediaComp
            case 2: return wallpaperComp
            case 3: return weatherComp
            default: return switcherComp
            }
        }
        onLoaded: {
            if (root.fadePhase === 1)
                root.enterShownPage()
            else if (root.fadePhase === 0) {
                if (item && typeof item.playEnter === "function")
                    item.playEnter()
                if (item && typeof item.forceActiveFocus === "function")
                    Qt.callLater(() => {
                        if (pageLoader.item)
                            pageLoader.item.forceActiveFocus()
                    })
            }
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
