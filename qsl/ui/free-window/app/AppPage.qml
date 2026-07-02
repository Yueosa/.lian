// AppPage — 应用搜索启动器
//     搜索 DesktopEntries，按使用频率+名称排序
//     右侧显示最近使用时间（数据轻量，从 usage JSON 读取）

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qsl.data.state

import "../../../JS/AppManager.js" as AppManager

Item {
    id: root

    signal closed()

    // === 数据 ===
    property var appsModel: []
    property var defaultModel: []
    property var usageMap: ({})     // { name: { count: N, last: timestamp } }
    readonly property string usagePath: Quickshell.env("HOME") + "/.cache/qsl/app_usage.json"

    // === 使用记录 ===
    FileView { id: usageFile; path: root.usagePath
        onLoaded: { try { let p = JSON.parse(text()); if (p && typeof p === "object") root.usageMap = p } catch (e) {} }
    }

    function saveUsage() {
        let dir = usagePath.replace(/\/[^/]*$/, "")
        let json = JSON.stringify(usageMap)
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p " + JSON.stringify(dir) + " && printf '%s' " + JSON.stringify(json) + " > " + JSON.stringify(usagePath)])
    }

    function recordUsage(name) {
        let m = Object.assign({}, root.usageMap)
        m[name] = { count: (m[name]?.count || 0) + 1, last: Date.now() }
        root.usageMap = m
        saveUsage()
    }

    function timeAgo(ts) {
        if (!ts) return ""
        let s = Math.max(0, Math.floor((Date.now() - ts) / 1000))
        if (s < 60)   return "刚刚"
        if (s < 3600) return Math.floor(s/60) + "分钟前"
        if (s < 86400) return Math.floor(s/3600) + "小时前"
        return Math.floor(s/86400) + "天前"
    }

    function search(text) {
        if ((text || "") === "") {
            if (defaultModel.length === 0) rebuildDefault()
            appsModel = defaultModel.slice(0)
        } else {
            appsModel = AppManager.updateFilter(text, DesktopEntries, root.usageMap)
        }
        appsList.currentIndex = 0
    }

    function rebuildDefault() {
        if (DesktopEntries.applications.values.length === 0) { defaultModel = []; return }
        defaultModel = AppManager.updateFilter("", DesktopEntries, root.usageMap)
    }

    function runSelected() {
        if (appsModel.length === 0 || appsList.currentIndex < 0) return
        let app = appsModel[appsList.currentIndex]
        if (!app || !app.appObj) return
        try {
            if (typeof app.appObj.execute === "function") app.appObj.execute()
            else if (app.appObj.execString) Quickshell.execDetached(["bash", "-lc", app.appObj.execString])
            else return
        } catch (e) {
            if (app.appObj.execString) Quickshell.execDetached(["bash", "-lc", app.appObj.execString])
            else return
        }
        recordUsage(app.name)
        root.closed()
    }

    // === 启动轮询 ===
    Timer { id: pollTimer; interval: 50; repeat: true; running: true
        onTriggered: {
            if (DesktopEntries.applications.values.length > 0) {
                rebuildDefault(); search(searchInput.text); running = false
            }
        }
    }
    onVisibleChanged: {
        if (visible) { searchInput.text = ""; searchInput.forceActiveFocus() }
    }

    // === 搜索框 ===
    ColumnLayout {
        anchors.fill: parent; spacing: Size.spacing.md

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40
            radius: Size.rounding.sm; color: Qt.rgba(Color.surfaceHighest.r, Color.surfaceHighest.g, Color.surfaceHighest.b, 0.6)

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: Size.spacing.sm

                Text { text: ""; font.family: Size.fontMono; font.pixelSize: Size.fontSize.lg; color: Color.onSurfaceVariant }

                TextInput {
                    id: searchInput; Layout.fillWidth: true
                    color: Color.onSurface; font.pixelSize: Size.fontSize.lg
                    selectionColor: Color.primary; selectedTextColor: Color.onPrimary; clip: true; focus: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索应用..."; color: Color.onSurfaceVariant; font.pixelSize: Size.fontSize.lg
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }
                    onTextChanged: root.search(text)
                    Keys.onReturnPressed:  e => { runSelected(); e.accepted = true }
                    Keys.onEnterPressed:   e => { runSelected(); e.accepted = true }
                    Keys.onUpPressed:      e => { appsList.prevItem(); e.accepted = true }
                    Keys.onDownPressed:    e => { appsList.nextItem(); e.accepted = true }
                    Keys.onEscapePressed:  e => { root.closed(); e.accepted = true }
                }

                // 清除按钮
                Text {
                    text: ""; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm
                    color: Color.onSurfaceVariant; visible: searchInput.text.length > 0
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
                }
            }
        }

        // === 应用列表 ===
        ListView {
            id: appsList
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: appsModel
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0; preferredHighlightEnd: height - 56

            highlight: Rectangle { color: Color.primary; radius: Size.rounding.sm }
            highlightMoveDuration: 120  // 平滑滚动动画

            function nextItem() {
                if (count === 0) return
                currentIndex = (currentIndex + 1) % count  // wrap
            }
            function prevItem() {
                if (count === 0) return
                currentIndex = (currentIndex - 1 + count) % count  // wrap
            }

            delegate: Item {
                width: ListView.view.width; height: 56

                MouseArea { anchors.fill: parent; onClicked: { appsList.currentIndex = index; root.runSelected() } }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: Size.spacing.lg

                    // 图标
                    Item { Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Rectangle { anchors.fill: parent; radius: Size.rounding.xs
                            color: Qt.rgba(Color.onSurface.r, Color.onSurface.g, Color.onSurface.b, 0.08)
                        }
                        Image {
                            anchors.fill: parent; sourceSize.width: 64; sourceSize.height: 64
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
                            visible: modelData.materialGlyph !== undefined
                            text: modelData.materialGlyph || "apps"
                            font.family: Size.fontIcon; font.pixelSize: Size.fontSize.title
                            color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                        }
                    }

                    // 名称
                    Text {
                        text: modelData.name || ""; textFormat: Text.StyledText
                        color: delegateItem.ListView.isCurrentItem ? Color.onPrimary : Color.onSurface
                        font.pixelSize: Size.fontSize.xl; Layout.fillWidth: true
                    }

                    // 最近使用时间
                    Text {
                        text: root.timeAgo(modelData.lastUsed || 0)
                        color: delegateItem.ListView.isCurrentItem ? Qt.rgba(Color.onPrimary.r, Color.onPrimary.g, Color.onPrimary.b, 0.7) : Color.onSurfaceVariant
                        font.pixelSize: Size.fontSize.xsm
                        visible: text !== ""
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // 提示
        Text {
            Layout.alignment: Qt.AlignRight
            text: "↑↓ 选择 · Enter 打开 · Esc 关闭"
            font.pixelSize: Size.fontSize.xsm; color: Color.onSurfaceVariant
        }
    }
}
