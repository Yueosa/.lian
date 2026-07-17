// AppPage — 应用搜索列表（FreeWindow 右栏）
// 视觉沿用旧 UnifiedLauncher AppPage；无底部按键提示
// 动画：高亮移动 / 列表过渡 / 选中缩放 / Enter 脉冲

import QtQuick
import QtQuick.Layouts
import Quickshell
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
    readonly property int visibleCount: appList.height > 0
        ? Math.max(1, Math.floor(appList.height / itemHeight))
        : 10

    function forceSearchFocus() {
        searchInput.forceActiveFocus()
    }

    function refresh(query) {
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
        if (filteredModel.length === 0 || appList.currentIndex < 0)
            return

        let appData = filteredModel[appList.currentIndex]
        if (!appData || !appData.appObj)
            return

        // Enter 脉冲后再启动，避免动画被关窗掐断
        enterPulse.targetIndex = appList.currentIndex
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
        interval: 130
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
            color: Color.withAlpha(Color.surfaceHighest, 0.45)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Size.spacing.sm

                Text {
                    text: "\uf002"
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.lg
                    color: Color.textMuted
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Color.text
                    font.pixelSize: Size.fontSize.lg
                    selectionColor: Color.primary
                    selectedTextColor: Color.textOnPrimary
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
                    Keys.onUpPressed: (event) => { appList.prev(); event.accepted = true }
                    Keys.onDownPressed: (event) => { appList.next(); event.accepted = true }
                    Keys.onLeftPressed: (event) => { appList.pageUp(); event.accepted = true }
                    Keys.onRightPressed: (event) => { appList.pageDown(); event.accepted = true }
                    Keys.onEscapePressed: (event) => { root.closeRequested(); event.accepted = true }
                }

                Text {
                    text: filteredModel.length + " 个"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.xsm
                    visible: filteredModel.length > 0
                }

                Text {
                    text: "\uf00d"
                    font.family: Size.fontMono
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
            highlightMoveDuration: 120
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
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 100 }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 200 }
            }

            delegate: Item {
                id: delegateItem
                width: ListView.view.width
                height: root.itemHeight

                readonly property bool current: ListView.isCurrentItem
                readonly property bool pulsing: enterPulse.running && enterPulse.targetIndex === index
                readonly property real contentScale: pulsing ? 1.12 : (current ? 1.06 : 1.0)

                MouseArea {
                    anchors.fill: parent
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
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
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
                            color: delegateItem.current ? Color.textOnPrimary : Color.text
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Size.fontSize.xl + 8

                        readonly property string appName: modelData.name || ""
                        readonly property var match: root.matchRange(appName, searchInput.text)
                        readonly property color textColor: delegateItem.current ? Color.textOnPrimary : Color.text

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
