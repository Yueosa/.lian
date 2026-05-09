import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

import "../../JS/AppManager.js" as AppManager

Item {
    id: root
    
    signal requestCloseLauncher()

    property var filteredAppsModel: []
    property var usageCounts: ({})
    readonly property string usageFile: Quickshell.env("HOME") + "/.cache/quickshell/launcher_usage.json"
    readonly property string legacyUsageFile: Quickshell.env("HOME") + "/.cache/quickshell_lian_usage.json"

    FileView {
        id: usageFileView
        path: root.usageFile
        onLoaded: {
            try {
                let parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object") root.usageCounts = parsed
            } catch (e) {}
        }
        onLoadFailed: {
            // 首次启动时缓存文件不存在，直接落盘空对象，避免重复 WARN。
            Quickshell.execDetached(["bash", "-c",
                "mkdir -p \"$(dirname '" + root.usageFile.replace(/'/g, "'\\''") + "')\" && " +
                "[ -e '" + root.usageFile.replace(/'/g, "'\\''") + "' ] || echo '{}' > '" + root.usageFile.replace(/'/g, "'\\''") + "'"])
        }
    }

    FileView {
        id: legacyUsageFileView
        path: root.legacyUsageFile
        onLoaded: {
            if (Object.keys(root.usageCounts).length > 0)
                return

            try {
                let parsed = JSON.parse(text())
                if (parsed && typeof parsed === "object")
                    root.usageCounts = parsed
            } catch (e) {}
        }
        onLoadFailed: {
            // 旧路径不存在属预期场景，吞掉警告。
        }
    }

    Process {
        id: saveUsageProcess
        running: false
    }

    function recordUsage(appName) {
        let counts = Object.assign({}, root.usageCounts)
        counts[appName] = (counts[appName] || 0) + 1
        root.usageCounts = counts
        let json = JSON.stringify(counts)
        let usageDir = root.usageFile.replace(/\/[^/]*$/, "")
        saveUsageProcess.command = ["bash", "-c",
            "mkdir -p " + JSON.stringify(usageDir) + " && " +
            "printf '%s' " + JSON.stringify(json) + " > " + JSON.stringify(root.usageFile)]
        saveUsageProcess.running = true
    }
    

    function decrementCurrentIndex() { appsList.decrementCurrentIndex() }
    function incrementCurrentIndex() { appsList.incrementCurrentIndex() }
    function forceSearchFocus() { searchInput.forceActiveFocus() }

    function search(text) {
        filteredAppsModel = AppManager.updateFilter(text, DesktopEntries, root.usageCounts)
        appsList.currentIndex = 0
    }

    // ==========================================
    // 异步等待机制
    // ==========================================
    Timer {
        id: startupPollTimer
        interval: 50 // 频率加快到 50 毫秒（0.05秒）
        repeat: true
        running: true 
        onTriggered: {
            // 直接去底层看一眼，有数据了吗？
            if (DesktopEntries.applications.values.length > 0) {
                // 有数据了！立刻执行搜索并渲染
                root.search(searchInput.text)
                // 任务完成，当场自毁。
                running = false 
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = ""
            search("")
            searchInput.forceActiveFocus()
        }
    }

    function highlightText(fullText, query) {
        let safeText = fullText.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        if (!query || query.trim() === "") return safeText
        let escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        let regex = new RegExp("(" + escapedQuery + ")", "gi")
        return safeText.replace(regex, "<u><b>$1</b></u>")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Sizes.spacing.md

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Sizes.rounding.xxl
            color: Qt.rgba(Colorscheme.surface_variant.r, Colorscheme.surface_variant.g, Colorscheme.surface_variant.b, 0.35)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: Sizes.spacing.sm

                Text {
                    text: "\uf002"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Sizes.font.lg
                    color: Colorscheme.on_surface_variant
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: Colorscheme.on_surface
                    font.pixelSize: Sizes.font.lg
                    selectionColor: Colorscheme.primary
                    selectedTextColor: Colorscheme.on_primary
                    clip: true
                    focus: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u641c\u7d22\u5e94\u7528..."
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: Sizes.font.lg
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }

                    onTextChanged: root.search(text)
                    Keys.onReturnPressed: (event) => { runSelectedApp(); event.accepted = true }
                    Keys.onEnterPressed: (event) => { runSelectedApp(); event.accepted = true }
                    Keys.onUpPressed: (event) => { appsList.decrementCurrentIndex(); event.accepted = true }
                    Keys.onDownPressed: (event) => { appsList.incrementCurrentIndex(); event.accepted = true }
                    Keys.onEscapePressed: (event) => { root.requestCloseLauncher(); event.accepted = true }
                }

                Text {
                    text: "\uf00d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface_variant
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
            id: appsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        
        model: filteredAppsModel
        
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.StrictlyEnforceRange 
        preferredHighlightBegin: 0
        preferredHighlightEnd: height - 56 
        
        highlight: Rectangle { 
            color: Colorscheme.primary
            radius: Sizes.rounding.normal 
        }
        highlightMoveDuration: 0 

        delegate: Item {
            id: delegateItem 
            width: ListView.view.width
            height: 56

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    appsList.currentIndex = index
                    runSelectedApp()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 16
                spacing: Sizes.spacing.lg

                Item {
                    id: iconRoot
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    property bool forceFontFallback: !!modelData.forceGlyph

                    Rectangle {
                        id: iconBg
                        anchors.fill: parent
                        radius: Sizes.rounding.small
                        color: Qt.rgba(Colorscheme.on_surface.r,
                                       Colorscheme.on_surface.g,
                                       Colorscheme.on_surface.b, 0.08)
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

                        source: {
                            if (modelData.assetAppId)
                                return "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/apps/" + modelData.assetAppId + ".svg"

                            let ic = modelData.icon
                            if (iconRoot.forceFontFallback) return ""
                            if (!ic) return ""
                            // 因为我们在 JS 里已经拼接成 /usr 开头了，所以这里会自动加上 file://
                            if (ic.startsWith("/")) return "file://" + ic
                            if (ic.startsWith("file://") || ic.startsWith("image://")) return ic
                            return "image://icon/" + ic
                        }
                        
                        property int failCount: 0
                        
                        onStatusChanged: {
                            // 【兜底策略】：
                            if (status === Image.Error) {
                                failCount++
                                if (failCount === 1) {
                                    // 第一次失败：退回到备用主题键
                                    if (modelData.fallbackIcon)
                                        source = "image://icon/" + modelData.fallbackIcon
                                } else if (failCount === 2) {
                                    // 第二次失败：系统里也彻底找不到，那就显示一个通用的执行文件图标
                                    source = "image://icon/application-x-executable"
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: iconRoot.forceFontFallback || appImage.status !== Image.Ready
                        text: modelData.materialGlyph || "apps"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: Sizes.font.display
                        color: delegateItem.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    }
                }

                Text {
                    text: root.highlightText(modelData.name, searchInput.text)
                    textFormat: Text.StyledText 
                    color: delegateItem.ListView.isCurrentItem ? Colorscheme.on_primary : Colorscheme.on_surface
                    font.pixelSize: Sizes.font.xl
                    font.bold: false 
                    Layout.fillWidth: true
                }
            }
        }
    }   // ListView

    }   // ColumnLayout

    function runSelectedApp() {
        if (filteredAppsModel.length > 0 && appsList.currentIndex >= 0) {
            let appData = filteredAppsModel[appsList.currentIndex]
            if (appData && appData.appObj) {
                let launched = false

                try {
                    if (typeof appData.appObj.execute === "function") {
                        appData.appObj.execute()
                        launched = true
                    }
                } catch (e) {
                    console.warn("Launcher execute() failed for", appData.name, e)
                }

                // 兼容某些桌面项（例如个别 IM 客户端）execute 不可用的场景。
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
                    root.recordUsage(appData.name)
            }
            root.requestCloseLauncher() 
        }
    }
}
