// AppPage — 应用列表 + 搜索
//     位于 AppWindow 右侧 60% 区域
//     每次按键触发 fuzzySearch + sort，200 个应用微秒级

import QtQuick
import QtQuick.Layouts
import Quickshell
import qsl.data.state
import qsl.data.free-window.app

Item {
    id: root

    signal launchRequested()   // → AppWindow.quickClose()
    signal closeRequested()    // → AppWindow.closeWindow()

    // === 数据 ===
    property var filteredModel: []
    property var cachedAllApps: []
    property string searchText: ""
    readonly property int itemHeight: 56

    // 计算当前可见项数（用于 page up/down）
    readonly property int visibleCount: {
        if (appList.height <= 0) return 10
        Math.max(1, Math.floor(appList.height / itemHeight))
    }

    // === 搜索入口 ===
    function search(text) {
        searchText = text || ""
        if (searchText === "") {
            filteredModel = cachedAllApps
        } else {
            filteredModel = cachedAllApps.filter(a => fuzzyMatch(a.name, searchText))
        }
        appList.currentIndex = 0
    }

    function fuzzyMatch(name, query) {
        // 逐字符匹配，O(n×m)，200 个应用微秒级
        let lowerName = name.toLowerCase()
        let lowerQuery = query.toLowerCase()
        let qi = 0
        for (let ni = 0; ni < lowerName.length && qi < lowerQuery.length; ni++) {
            if (lowerName[ni] === lowerQuery[qi]) qi++
        }
        return qi === lowerQuery.length
    }

    // === 初始化（DesktopEntries 就绪后只做一次） ===
    function rebuild() {
        if (DesktopEntries.applications.values.length === 0) return
        let apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        apps.sort((a, b) => {
            let ua = Usage.usageMap[a.name]
            let ub = Usage.usageMap[b.name]
            let ca = ua?.count || 0
            let cb = ub?.count || 0
            if (cb !== ca) return cb - ca
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
        })
        cachedAllApps = apps
        filteredModel = apps
    }

    Component.onCompleted: rebuild()

    // === 启动应用 ===
    function launch(index) {
        if (index < 0 || index >= filteredModel.length) return
        let app = filteredModel[index]
        if (!app) return
        try {
            if (typeof app.execute === "function") app.execute()
            else if (app.execString) Quickshell.execDetached(["bash", "-lc", app.execString])
        } catch (e) {
            if (app.execString) Quickshell.execDetached(["bash", "-lc", app.execString])
        }
        Usage.recordLaunch(app.name)
        root.launchRequested()
    }

    // === 时间格式化 ===
    function timeAgo(ts) {
        if (!ts) return ""
        let s = Math.max(0, Math.floor((Date.now() - ts) / 1000))
        if (s < 60)   return "刚刚"
        if (s < 3600) return Math.floor(s/60) + "分钟前"
        if (s < 86400) return Math.floor(s/3600) + "小时前"
        return Math.floor(s/86400) + "天前"
    }

    // ============================================================
    // UI
    // ============================================================

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: Size.spacing.md

        // 搜索框
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Size.rounding.sm
            color: Qt.rgba(Color.surfaceHighest.r, Color.surfaceHighest.g, Color.surfaceHighest.b, 0.5)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                spacing: Size.spacing.sm

                Text {
                    text: ""
                    font.family: Size.fontMono; font.pixelSize: Size.fontSize.lg
                    color: Color.onSurfaceVariant
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Color.onSurface; font.pixelSize: Size.fontSize.lg
                    selectionColor: Color.primary; selectedTextColor: Color.onPrimary
                    clip: true; focus: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索应用..."
                        color: Color.onSurfaceVariant; font.pixelSize: Size.fontSize.lg
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }

                    onTextChanged: root.search(text)

                    Keys.onReturnPressed:  e => { root.launch(appList.currentIndex); e.accepted = true }
                    Keys.onEnterPressed:   e => { root.launch(appList.currentIndex); e.accepted = true }
                    Keys.onUpPressed:      e => { appList.prev(); e.accepted = true }
                    Keys.onDownPressed:    e => { appList.next(); e.accepted = true }
                    Keys.onLeftPressed:    e => { appList.pageUp(); e.accepted = true }
                    Keys.onRightPressed:   e => { appList.pageDown(); e.accepted = true }
                    Keys.onEscapePressed:  e => { root.closeRequested(); e.accepted = true }
                }

                // 应用数量
                Text {
                    text: filteredModel.length + " 个"
                    color: Color.onSurfaceVariant; font.pixelSize: Size.fontSize.xsm
                    visible: filteredModel.length > 0
                }

                // 清除
                Text {
                    text: ""
                    font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm
                    color: Color.onSurfaceVariant
                    visible: searchInput.text.length > 0
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        // 应用列表
        ListView {
            id: appList
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: filteredModel

            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: height - itemHeight
            highlightMoveDuration: 120
            highlight: Rectangle { color: Color.primary; radius: Size.rounding.sm }

            function next() { if (count > 0) currentIndex = (currentIndex + 1) % count }
            function prev() { if (count > 0) currentIndex = (currentIndex - 1 + count) % count }
            function pageDown() { if (count > 0) currentIndex = Math.min(currentIndex + root.visibleCount, count - 1) }
            function pageUp()   { if (count > 0) currentIndex = Math.max(currentIndex - root.visibleCount, 0) }

            // 搜索过滤动画 —— 未匹配的滑出，匹配的滑入
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                NumberAnimation { property: "x";      from: 40; to: 0; duration: 200 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                NumberAnimation { property: "x";      to: 40; duration: 200 }
            }
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 200 }
            }

            delegate: Item {
                width: ListView.view.width; height: root.itemHeight

                MouseArea {
                    anchors.fill: parent
                    onClicked: { appList.currentIndex = index; root.launch(index) }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 16
                    spacing: Size.spacing.lg

                    // 图标
                    Item {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Rectangle {
                            anchors.fill: parent; radius: Size.rounding.xs
                            color: Qt.rgba(Color.onSurface.r, Color.onSurface.g, Color.onSurface.b, 0.08)
                        }
                        Image {
                            id: iconImage
                            anchors.fill: parent
                            sourceSize.width: 64; sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true
                            source: {
                                let ic = modelData.icon || ""
                                if (ic.startsWith("/")) return "file://" + ic
                                if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                                return ic ? "image://icon/" + ic : ""
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: (modelData.name || "?")[0]
                            font.pixelSize: Size.fontSize.xl; font.bold: true
                            color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                            visible: iconImage.status !== Image.Ready
                        }
                    }

                    // 名称
                    Text {
                        text: modelData.name || ""
                        color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                        font.pixelSize: Size.fontSize.xl; Layout.fillWidth: true
                    }

                    // 最后使用时间
                    Text {
                        text: {
                            let u = Usage.usageMap[modelData.name]
                            return u?.last ? root.timeAgo(u.last) : ""
                        }
                        color: delegateItem.ListView.isCurrentItem
                            ? Qt.rgba(Color.onPrimary.r, Color.onPrimary.g, Color.onPrimary.b, 0.7)
                            : Color.onSurfaceVariant
                        font.pixelSize: Size.fontSize.xsm
                        visible: text !== ""
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 底部提示
        Text {
            Layout.alignment: Qt.AlignRight
            text: "↑↓ 选择 · ←→ 翻页 · Enter 打开 · Esc 关闭"
            font.pixelSize: Size.fontSize.xsm; color: Color.onSurfaceVariant
        }
    }
}
