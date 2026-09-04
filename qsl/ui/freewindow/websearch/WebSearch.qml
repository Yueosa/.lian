// WebSearch — Web 搜索窗口（Super+X）
// 屏幕中上方窄长条 + 引擎选择 + 搜索建议
// Enter → xdg-open 跳浏览器
//
// 性能：
//   - 关闭时 mask=0 不挡桌面
//   - 搜索建议 debounce 300ms，最多 8 条
//   - 无 Image/blur

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Components
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

    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    property real _slideY: open ? 0 : -80
    property real _opacity: open ? 1 : 0

    Behavior on _slideY {
        Anim {
            id: slideAnim
            type: Anim.Spatial
        }
    }
    Behavior on _opacity {
        Anim { type: Anim.Effects }
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

        // 高度 = 内容 + 上下 padding（否则 topMargin 会把行推出可视区）
        Rectangle {
            id: bar
            width: root.barWidth
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.barTop + root._slideY
            height: barInner.implicitHeight + Size.spacing.lg * 2
            visible: root.contentActive
            opacity: root._opacity
            radius: Size.rounding.xl
            color: Color.withAlpha(Color.surfaceContainerHigh, 0.97)
            border.width: 2
            border.color: Color.secondaryFixed

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: barInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Size.spacing.lg
                anchors.rightMargin: Size.spacing.lg
                spacing: Size.spacing.sm

                // 输入行：固定 36px，子项全部 verticalCenter
                Item {
                    width: parent.width
                    height: 36

                    Row {
                        anchors.fill: parent
                        spacing: Size.spacing.sm

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: engineLbl.implicitWidth + 20
                            height: 32
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

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            width: {
                                const engW = engineLbl.implicitWidth + 20
                                return Math.max(80, parent.width - engW - 32 - parent.spacing * 2)
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Color.text
                                font.pixelSize: Size.fontSize.md
                                font.family: Size.fontSans
                                clip: true
                                selectByMouse: true

                                onTextChanged: {
                                    suggestList.currentIndex = -1
                                    suggestDebounce.restart()
                                }

                                Keys.onReturnPressed: (event) => {
                                    if (suggestList.currentIndex >= 0
                                        && suggestList.currentIndex < root.suggestions.length)
                                        root.doSearch(root.suggestions[suggestList.currentIndex])
                                    else
                                        root.doSearch()
                                    event.accepted = true
                                }
                                Keys.onEnterPressed: (event) => {
                                    if (suggestList.currentIndex >= 0
                                        && suggestList.currentIndex < root.suggestions.length)
                                        root.doSearch(root.suggestions[suggestList.currentIndex])
                                    else
                                        root.doSearch()
                                    event.accepted = true
                                }
                                Keys.onDownPressed: (event) => {
                                    if (root.suggestions.length === 0) return
                                    suggestList.currentIndex = Math.min(
                                        suggestList.currentIndex + 1,
                                        root.suggestions.length - 1)
                                    event.accepted = true
                                }
                                Keys.onUpPressed: (event) => {
                                    if (suggestList.currentIndex <= 0)
                                        suggestList.currentIndex = -1
                                    else
                                        suggestList.currentIndex -= 1
                                    event.accepted = true
                                }
                                Keys.onTabPressed: (event) => {
                                    root.cycleEngine()
                                    event.accepted = true
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !searchInput.text && !searchInput.activeFocus
                                    text: "搜索…"
                                    color: Color.textMuted
                                    font: searchInput.font
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
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
                }

                ListView {
                    id: suggestList
                    width: parent.width
                    height: root.suggestions.length > 0
                        ? Math.min(root.suggestions.length, 8) * 38 : 0
                    visible: root.suggestions.length > 0
                    clip: true
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
                }
            }
        }
    }
}
