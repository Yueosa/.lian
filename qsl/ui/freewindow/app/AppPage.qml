// AppPage — 应用搜索列表（FreeWindow 右栏）
// 视觉沿用旧 UnifiedLauncher AppPage；无底部按键提示
// 动画：高亮移动 / 列表过渡 / 选中缩放
//       Enter：选中项留下放大，其余项右滑淡出

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.freewindow.app

Item {
    id: root

    signal launchRequested()
    signal closeRequested()

    property var filteredModel: []
    property string searchText: ""
    readonly property int itemHeight: 56
    readonly property int searchHeight: 40
    readonly property int iconSize: 36
    readonly property int exitSlide: 72
    readonly property int launchAnimMs: 180
    readonly property int visibleCount: appList.height > 0
        ? Math.max(1, Math.floor(appList.height / itemHeight))
        : 10

    // 启动动画中：禁止重复触发 / 方向键
    property bool launching: false
    property int launchIndex: -1
    // reset 时关掉 Behavior，避免再打开时看到回弹
    property bool animEnabled: true

    function forceSearchFocus() {
        searchInput.forceActiveFocus()
    }

    // 每次打开窗口：清空搜索、恢复完整列表、选中第一项
    function reset() {
        animEnabled = false
        launching = false
        launchIndex = -1
        if (searchInput.text !== "")
            searchInput.text = ""
        else
            refresh("")
        appList.currentIndex = 0
        forceSearchFocus()
        Qt.callLater(function() { root.animEnabled = true })
    }

    function refresh(query) {
        if (launching)
            return
        searchText = query || ""
        filteredModel = Apps.search(searchText)
        appList.currentIndex = 0
    }

    function matchRange(fullText, query) {
        const text = fullText || ""
        const q = (query || "").trim()
        if (q === "")
            return { start: -1, length: 0 }

        const start = text.toLowerCase().indexOf(q.toLowerCase())
        return start >= 0 ? { start, length: q.length } : { start: -1, length: 0 }
    }

    function runSelectedApp() {
        if (launching)
            return
        if (filteredModel.length === 0 || appList.currentIndex < 0)
            return

        let appData = filteredModel[appList.currentIndex]
        if (!appData || !appData.appObj)
            return

        launching = true
        launchIndex = appList.currentIndex
        // 退场动画播完再真正启动
        enterPulse.targetIndex = launchIndex
        enterPulse.restart()
    }

    function launchAt(index) {
        if (index < 0 || index >= filteredModel.length)
            return
        let appData = filteredModel[index]
        if (!appData || !appData.appObj)
            return

        let launched = false
        try {
            if (typeof appData.appObj.execute === "function") {
                appData.appObj.execute()
                launched = true
            }
        } catch (e) {
            console.warn("App execute failed:", appData.name, e)
        }

        if (!launched) {
            const execString = (appData.appObj.execString || appData.appObj.exec || "").trim()
            const desktopId = (appData.appObj.desktopId || appData.appObj.id || "").trim()
            if (execString.length > 0) {
                Quickshell.execDetached(["bash", "-lc", execString])
                launched = true
            } else if (desktopId.length > 0) {
                const escapedId = desktopId.replace(/'/g, "'\\''")
                Quickshell.execDetached(["bash", "-lc", "gtk-launch '" + escapedId + "'"])
                launched = true
            }
        }

        if (launched)
            Apps.recordLaunch(appData.name)
        root.launchRequested()
    }

    Connections {
        target: Apps
        function onCatalogChanged() { root.refresh(searchInput.text) }
    }

    Component.onCompleted: {
        if (Apps.ready)
            refresh("")
    }

    Timer {
        id: enterPulse
        property int targetIndex: -1
        interval: root.launchAnimMs
        repeat: false
        onTriggered: root.launchAt(targetIndex)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        // 搜索框
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.searchHeight
            radius: Size.rounding.full
            color: Color.surfaceContainerHighest

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Size.spacing.sm

                Text {
                    text: "search"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.lg
                    color: Color.textMuted
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Color.text
                    font.pixelSize: Size.fontSize.lg
                    selectionColor: Color.primary
                    selectedTextColor: Color.primaryText
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索应用..."
                        color: Color.textMuted
                        font.pixelSize: Size.fontSize.lg
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }

                    onTextChanged: root.refresh(text)
                    Keys.onReturnPressed: (event) => { root.runSelectedApp(); event.accepted = true }
                    Keys.onEnterPressed: (event) => { root.runSelectedApp(); event.accepted = true }
                    Keys.onUpPressed: (event) => {
                        if (!root.launching) appList.prev()
                        event.accepted = true
                    }
                    Keys.onDownPressed: (event) => {
                        if (!root.launching) appList.next()
                        event.accepted = true
                    }
                    Keys.onLeftPressed: (event) => {
                        if (!root.launching) appList.pageUp()
                        event.accepted = true
                    }
                    Keys.onRightPressed: (event) => {
                        if (!root.launching) appList.pageDown()
                        event.accepted = true
                    }
                    Keys.onEscapePressed: (event) => {
                        if (!root.launching)
                            root.closeRequested()
                        event.accepted = true
                    }
                }

                Text {
                    text: filteredModel.length + " 个"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.xsm
                    visible: filteredModel.length > 0
                }

                Text {
                    text: "close"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.sm
                    color: Color.textMuted
                    visible: searchInput.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filteredModel
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height - root.itemHeight
            highlightMoveDuration: Size.anim.durFast
            highlight: Rectangle {
                color: Color.primary
                radius: Size.rounding.md
            }

            function next() {
                if (count > 0)
                    currentIndex = (currentIndex + 1) % count
            }
            function prev() {
                if (count > 0)
                    currentIndex = (currentIndex - 1 + count) % count
            }
            function pageDown() {
                if (count > 0)
                    currentIndex = Math.min(currentIndex + root.visibleCount, count - 1)
            }
            function pageUp() {
                if (count > 0)
                    currentIndex = Math.max(currentIndex - root.visibleCount, 0)
            }

            add: Transition {
                Anim { property: "opacity"; from: 0; to: 1; type: Anim.EffectsFast }
            }
            remove: Transition {
                Anim { property: "opacity"; to: 0; type: Anim.EffectsFast }
            }
            displaced: Transition {
                Anim { property: "y"; type: Anim.Spatial }
            }

            delegate: Item {
                id: delegateItem
                width: ListView.view.width
                height: root.itemHeight

                readonly property bool current: ListView.isCurrentItem
                readonly property bool chosen: root.launching && index === root.launchIndex
                readonly property bool exiting: root.launching && index !== root.launchIndex
                readonly property real contentScale: chosen ? 1.12 : (current && !root.launching ? 1.06 : 1.0)

                // 未选中项：向右滑出并淡出
                opacity: exiting ? 0 : 1
                x: exiting ? root.exitSlide : 0

                Behavior on opacity {
                    enabled: root.animEnabled
                    Anim { type: Anim.Exit }
                }
                Behavior on x {
                    enabled: root.animEnabled
                    Anim { type: Anim.Exit }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.launching
                    onClicked: {
                        appList.currentIndex = index
                        root.runSelectedApp()
                    }
                }

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: Size.spacing.lg
                    scale: delegateItem.contentScale
                    transformOrigin: Item.Left

                    Behavior on scale {
                        enabled: root.animEnabled
                        Anim { type: Anim.EffectsFast }
                    }

                    Item {
                        id: iconRoot
                        Layout.preferredWidth: root.iconSize
                        Layout.preferredHeight: root.iconSize
                        property bool forceFontFallback: !!modelData.forceGlyph

                        Rectangle {
                            anchors.fill: parent
                            radius: Size.rounding.xs
                            color: Color.withAlpha(Color.text, 0.08)
                            visible: iconRoot.forceFontFallback || appImage.status !== Image.Ready
                        }

                        Image {
                            id: appImage
                            anchors.fill: parent
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            cache: false
                            visible: status === Image.Ready && !iconRoot.forceFontFallback
                            property int failCount: 0

                            source: {
                                if (modelData.assetAppId)
                                    return "file://" + Apps.logoDir + "/" + modelData.assetAppId + ".svg"
                                let ic = modelData.icon
                                if (iconRoot.forceFontFallback || !ic)
                                    return ""
                                if (ic.startsWith("/"))
                                    return "file://" + ic
                                if (ic.startsWith("file://") || ic.startsWith("image://"))
                                    return ic
                                return "image://icon/" + ic
                            }

                            onStatusChanged: {
                                if (status !== Image.Error)
                                    return
                                failCount++
                                if (failCount === 1 && modelData.fallbackIcon)
                                    source = "image://icon/" + modelData.fallbackIcon
                                else if (failCount === 2)
                                    source = "image://icon/application-x-executable"
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: iconRoot.forceFontFallback || appImage.status !== Image.Ready
                            text: modelData.materialGlyph || "apps"
                            font.family: Size.fontIcon
                            font.pixelSize: Size.fontSize.xl
                            color: delegateItem.current ? Color.primaryText : Color.text
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Size.fontSize.xl + 8

                        readonly property string appName: modelData.name || ""
                        readonly property var match: root.matchRange(appName, searchInput.text)
                        readonly property color textColor: delegateItem.current ? Color.primaryText : Color.text

                        Text {
                            id: appNameBefore
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.match.start >= 0 ? parent.appName.slice(0, parent.match.start) : parent.appName
                            color: parent.textColor
                            font.pixelSize: Size.fontSize.xl
                        }

                        Text {
                            id: appNameMatch
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: appNameBefore.right
                            visible: parent.match.start >= 0
                            text: visible ? parent.appName.slice(parent.match.start, parent.match.start + parent.match.length) : ""
                            color: parent.textColor
                            font.pixelSize: Size.fontSize.xl
                            font.bold: true
                            font.underline: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: appNameMatch.visible ? appNameMatch.right : appNameBefore.right
                            visible: parent.match.start >= 0
                            text: visible ? parent.appName.slice(parent.match.start + parent.match.length) : ""
                            color: parent.textColor
                            font.pixelSize: Size.fontSize.xl
                        }
                    }
                }
            }
        }
    }
}
