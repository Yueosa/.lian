// AppPage — 应用列表 + 搜索（FreeWindow 右 40% 区域）

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.data.freewindow.app

Item {
    id: root

    signal launchRequested()
    signal closeRequested()

    // === 数据 ===
    property var filteredModel: []
    property var cachedAllApps: []
    property string searchText: ""
    readonly property int itemHeight: 56
    readonly property int visibleCount: appList.height > 0 ? Math.max(1, Math.floor(appList.height / itemHeight)) : 10

    // === 搜索 ===
    function search(text) {
        searchText = text || ""
        filteredModel = searchText === "" ? cachedAllApps
            : cachedAllApps.filter(a => fuzzyMatch(a.name, searchText))
        appList.currentIndex = 0
    }

    function fuzzyMatch(name, query) {
        let ln = name.toLowerCase(), lq = query.toLowerCase(), qi = 0
        for (let ni = 0; ni < ln.length && qi < lq.length; ni++)
            if (ln[ni] === lq[qi]) qi++
        return qi === lq.length
    }

    // === 桌面项就绪（事件驱动，不轮询） ===
    function rebuild() {
        if (DesktopEntries.applications.values.length === 0) return
        let apps = DesktopEntries.applications.values.filter(a => !a.noDisplay)
        apps.sort((a, b) => {
            let ua = Usage.usageMap[a.name], ub = Usage.usageMap[b.name]
            let ca = ua?.count || 0, cb = ub?.count || 0
            if (cb !== ca) return cb - ca
            return (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase())
        })
        cachedAllApps = apps
        filteredModel = apps
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (DesktopEntries.applications.values.length > 0) root.rebuild()
        }
    }

    Component.onCompleted: { if (DesktopEntries.applications.values.length > 0) rebuild() }

    // === 启动 ===
    function launch(index) {
        if (index < 0 || index >= filteredModel.length) return
        let app = filteredModel[index]; if (!app) return
        try {
            if (typeof app.execute === "function") app.execute()
            else if (app.execString) Quickshell.execDetached(["bash", "-lc", app.execString])
        } catch (e) { if (app.execString) Quickshell.execDetached(["bash", "-lc", app.execString]) }
        Usage.recordLaunch(app.name)
        root.launchRequested()
    }

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
        spacing: Size.spacing.md

        // 搜索框
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40
            radius: Size.rounding.sm
            color: Qt.rgba(Color.surfaceHighest.r, Color.surfaceHighest.g, Color.surfaceHighest.b, 0.5)

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                spacing: Size.spacing.sm

                Text { text: ""; font.family: Size.fontMono; font.pixelSize: Size.fontSize.lg; color: Color.onSurfaceVariant }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true; color: Color.onSurface; font.pixelSize: Size.fontSize.lg
                    selectionColor: Color.primary; selectedTextColor: Color.onPrimary; clip: true
                    // 主动拿焦点 — 通过 AppWindow 的 onOpenChanged 调用
                    function takeFocus() { forceActiveFocus() }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索应用..."; color: Color.onSurfaceVariant; font.pixelSize: Size.fontSize.lg
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

                Text { text: filteredModel.length + " 个"; color: Color.onSurfaceVariant; font.pixelSize: Size.fontSize.xsm; visible: filteredModel.length > 0 }

                Text {
                    text: ""; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm
                    color: Color.onSurfaceVariant; visible: searchInput.text.length > 0
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
                }
            }
        }

        // 应用列表
        ListView {
            id: appList
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: filteredModel
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0; preferredHighlightEnd: height - itemHeight
            highlightMoveDuration: 120
            highlight: Rectangle { color: Color.primary; radius: Size.rounding.sm }

            function next() { if (count > 0) currentIndex = (currentIndex + 1) % count }
            function prev() { if (count > 0) currentIndex = (currentIndex - 1 + count) % count }
            function pageDown() { if (count > 0) currentIndex = Math.min(currentIndex + root.visibleCount, count - 1) }
            function pageUp()   { if (count > 0) currentIndex = Math.max(currentIndex - root.visibleCount, 0) }

            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }
            displaced: Transition { NumberAnimation { property: "y"; duration: 200 } }

            delegate: Item {
                width: ListView.view.width; height: root.itemHeight
                MouseArea { anchors.fill: parent; onClicked: { appList.currentIndex = index; root.launch(index) } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16
                    spacing: Size.spacing.lg

                    // 图标
                    Item { Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Rectangle { anchors.fill: parent; radius: Size.rounding.xs
                            color: Qt.rgba(Color.onSurface.r, Color.onSurface.g, Color.onSurface.b, 0.08)
                        }
                        Image {
                            id: iconImage; anchors.fill: parent
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
                            anchors.centerIn: parent; text: (modelData.name || "?")[0]
                            font.pixelSize: Size.fontSize.xl; font.bold: true
                            color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                            visible: iconImage.status !== Image.Ready
                        }
                    }

                    Text {
                        text: modelData.name || ""
                        color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                        font.pixelSize: Size.fontSize.xl; Layout.fillWidth: true
                    }

                    Text {
                        text: { let u = Usage.usageMap[modelData.name]; return u?.last ? root.timeAgo(u.last) : "" }
                        color: delegateItem.ListView.isCurrentItem ? Qt.rgba(Color.onPrimary.r, Color.onPrimary.g, Color.onPrimary.b, 0.7) : Color.onSurfaceVariant
                        font.pixelSize: Size.fontSize.xsm; visible: text !== ""
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignRight; text: "↑↓ 选择 · ←→ 翻页 · Enter 打开 · Esc 关闭"
            font.pixelSize: Size.fontSize.xsm; color: Color.onSurfaceVariant
        }
    }
}
