// WebSearch — Web 搜索窗口（Super+X）
// 屏幕中上方窄长条 + 引擎选择 + 搜索建议
// Enter → xdg-open 跳浏览器
//
// 性能：
//   - 关闭时 mask=0 不挡桌面
//   - 搜索建议 debounce 300ms，最多 8 条
//   - 无 Image/blur/layer.enabled

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: true

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "qsl-websearch"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    property bool open: false
    readonly property bool contentActive: open || slideAnim.running

    readonly property int barWidth: Math.min(640, width - 80)
    readonly property int barTop: 180

    property int _engineIdx: 0
    readonly property var engines: [
        { name: "Google", url: "https://www.google.com/search?q=", suggest: "https://suggestqueries.google.com/complete/search?client=firefox&q=" },
        { name: "Bing",   url: "https://www.bing.com/search?q=",   suggest: "" },
        { name: "Baidu",  url: "https://www.baidu.com/s?wd=",      suggest: "" }
    ]
    readonly property var currentEngine: engines[_engineIdx]

    property var suggestions: []

    function toggle() { open ? closeWindow() : openWindow() }

    function openWindow() {
        Island.captureFocus()
        open = true
        Qt.callLater(function() {
            searchInput.text = ""
            searchInput.forceActiveFocus()
            suggestions = []
        })
    }

    function closeWindow() {
        if (!open) return
        open = false
        suggestions = []
        Island.restoreFocus()
    }

    function doSearch(query) {
        const q = (query || searchInput.text).trim()
        if (!q) return
        _openProc.command = ["xdg-open", currentEngine.url + encodeURIComponent(q)]
        _openProc.running = true
        closeWindow()
    }

    function cycleEngine() {
        _engineIdx = (_engineIdx + 1) % engines.length
    }

    // ---- 搜索建议 debounce ----
    Timer {
        id: suggestDebounce
        interval: 300
        repeat: false
        onTriggered: root._fetchSuggestions()
    }

    function _fetchSuggestions() {
        const q = searchInput.text.trim()
        if (!q || !currentEngine.suggest) {
            suggestions = []
            return
        }
        const xhr = new XMLHttpRequest()
        const self = root
        xhr.open("GET", currentEngine.suggest + encodeURIComponent(q))
        xhr.timeout = 3000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { self.suggestions = []; return }
            try {
                const j = JSON.parse(xhr.responseText)
                self.suggestions = Array.isArray(j[1]) ? j[1].slice(0, 8) : []
            } catch(e) {
                self.suggestions = []
            }
        }
        xhr.ontimeout = function() { self.suggestions = [] }
        try { xhr.send() } catch(e) { self.suggestions = [] }
    }

    Process {
        id: _openProc
        running: false
    }

    // ---- mask ----
    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    // ---- 动画 ----
    property real _slideY: open ? 0 : -80
    property real _opacity: open ? 1 : 0

    Behavior on _slideY {
        NumberAnimation {
            id: slideAnim
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    Behavior on _opacity {
        NumberAnimation { duration: 200 }
    }

    FocusScope {
        anchors.fill: parent
        enabled: root.open
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }

        // ---- 搜索栏 ----
        Rectangle {
            id: bar
            width: root.barWidth
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.barTop + root._slideY
            height: barCol.implicitHeight
            visible: root.contentActive
            opacity: root._opacity
            radius: Size.rounding.xl
            color: Color.withAlpha(Color.surfaceHigh, 0.97)
            border.width: 2
            border.color: Color.secondaryFixed

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: barCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Size.spacing.lg
                anchors.top: parent.top
                anchors.topMargin: Size.spacing.lg
                anchors.bottomMargin: Size.spacing.lg
                spacing: Size.spacing.sm

                // 输入行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.sm

                    // 引擎切换
                    Rectangle {
                        width: engineLbl.implicitWidth + 20
                        height: 36
                        radius: Size.rounding.sm
                        color: engineMa.containsMouse
                            ? Color.withAlpha(Color.primary, 0.15)
                            : Color.withAlpha(Color.text, 0.06)
                        Text {
                            id: engineLbl
                            anchors.centerIn: parent
                            text: root.currentEngine.name
                            color: Color.primary
                            font.pixelSize: Size.fontSize.sm
                            font.bold: true
                        }
                        MouseArea {
                            id: engineMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleEngine()
                        }
                    }

                    // 搜索输入框
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        verticalAlignment: Text.AlignVCenter
                        color: Color.text
                        font.pixelSize: Size.fontSize.md
                        font.family: Size.fontSans
                        clip: true
                        selectByMouse: true

                        onTextChanged: suggestDebounce.restart()

                        Keys.onReturnPressed: root.doSearch()
                        Keys.onEnterPressed: root.doSearch()
                        Keys.onDownPressed: {
                            if (suggestList.count > 0)
                                suggestList.currentIndex = 0
                        }
                        Keys.onTabPressed: root.cycleEngine()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text && !searchInput.activeFocus
                            text: "搜索…"
                            color: Color.textMuted
                            font: searchInput.font
                        }
                    }

                    // 搜索按钮
                    Rectangle {
                        width: 36; height: 36
                        radius: Size.rounding.sm
                        color: searchBtnMa.containsMouse
                            ? Color.withAlpha(Color.primary, 0.15)
                            : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "\ue8b6"
                            font.family: Size.fontIcon
                            font.pixelSize: 20
                            color: Color.primary
                        }
                        MouseArea {
                            id: searchBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.doSearch()
                        }
                    }
                }

                // 搜索建议列表
                ListView {
                    id: suggestList
                    Layout.fillWidth: true
                    Layout.preferredHeight: contentHeight
                    visible: root.suggestions.length > 0
                    interactive: false
                    model: root.suggestions
                    currentIndex: -1
                    spacing: 2

                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: ListView.view ? ListView.view.width : 0
                        height: 36
                        radius: Size.rounding.sm
                        color: sugItemMa.containsMouse || suggestList.currentIndex === index
                            ? Color.withAlpha(Color.text, 0.06) : "transparent"

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Size.spacing.sm
                            anchors.right: parent.right
                            anchors.rightMargin: Size.spacing.sm
                            text: modelData
                            color: Color.text
                            font.pixelSize: Size.fontSize.sm
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: sugItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.doSearch(modelData)
                        }
                    }

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < count)
                            root.doSearch(root.suggestions[currentIndex])
                    }
                    Keys.onUpPressed: {
                        if (currentIndex > 0) currentIndex--
                        else { currentIndex = -1; searchInput.forceActiveFocus() }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) currentIndex++
                    }
                }

                // 底部间距
                Item { Layout.preferredHeight: Size.spacing.sm }
            }
        }
    }
}
