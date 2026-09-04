// ClipboardPage — 剪贴板列表（全宽 FreeWindow）
// 文本每条一行；连续图片按一行多列分组
// 键盘：Up/Down 跨行（图片行尽量保持列），Left/Right 行内移动并在尽头换行
// 动画：选中项留下，其余项右滑淡出后执行 paste
//
// 内存/性能：
//   - 缩略图 Image cache:false + sourceSize(2×cell)；关窗 release 清内存，JSON 缓存留盘
//   - 显示：PreserveAspectFit 原比例完整可见（letterbox），非 Crop 裁切
//   - 圆角：cell.layer + OpacityMask（仅 Ready 时开）
//   - ListView reuseItems；无空态文案（避免关窗闪「剪贴板为空」）

import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.freewindow.clipboard

Item {
    id: root

    signal pasteRequested()
    signal closeRequested()

    readonly property int searchHeight: 40
    readonly property int textRowHeight: 46
    readonly property int imageCellW: 156
    readonly property int imageCellH: 112
    readonly property int cellSpacing: Size.spacing.sm
    readonly property int rowSpacing: Size.spacing.sm
    readonly property int navInset: Size.spacing.sm
    readonly property int launchAnimMs: 180
    readonly property int exitSlide: 72

    property int currentRow: 0
    property int currentCol: 0
    property var rows: []

    property bool launching: false
    property int launchRow: -1
    property int launchCol: -1
    property bool animEnabled: true

    function imagesPerRow() {
        const w = listView.width - navInset * 2
        if (w <= 0)
            return 1
        return Math.max(1, Math.floor((w + cellSpacing) / (imageCellW + cellSpacing)))
    }

    function buildRows() {
        const items = Clipboard.filtered || []
        const perRow = imagesPerRow()
        const out = []
        let i = 0
        while (i < items.length) {
            if (items[i].kind === "image") {
                const group = []
                while (i < items.length && items[i].kind === "image") {
                    group.push(items[i])
                    i++
                }
                for (let j = 0; j < group.length; j += perRow)
                    out.push({ type: "images", entries: group.slice(j, j + perRow) })
            } else {
                out.push({ type: "text", entries: [items[i]] })
                i++
            }
        }
        rows = out
        clampSelection()
    }

    function clampSelection() {
        if (rows.length === 0) {
            currentRow = 0
            currentCol = 0
            return
        }
        if (currentRow > rows.length - 1)
            currentRow = rows.length - 1
        if (currentRow < 0)
            currentRow = 0
        const row = rows[currentRow]
        const maxCol = row && row.entries ? row.entries.length - 1 : 0
        if (currentCol > maxCol)
            currentCol = maxCol
        if (currentCol < 0)
            currentCol = 0
    }

    function selectedEntry() {
        if (currentRow < 0 || currentRow >= rows.length)
            return null
        const row = rows[currentRow]
        if (!row || !row.entries || row.entries.length === 0)
            return null
        const col = row.type === "images"
            ? Math.min(currentCol, row.entries.length - 1)
            : 0
        return row.entries[col]
    }

    function moveDown() {
        if (rows.length === 0 || currentRow >= rows.length - 1)
            return
        currentRow++
        const row = rows[currentRow]
        if (row && row.type === "images")
            currentCol = Math.min(currentCol, row.entries.length - 1)
        else
            currentCol = 0
    }

    function moveUp() {
        if (rows.length === 0 || currentRow <= 0)
            return
        currentRow--
        const row = rows[currentRow]
        if (row && row.type === "images")
            currentCol = Math.min(currentCol, row.entries.length - 1)
        else
            currentCol = 0
    }

    // Left/Right：图片行内移动；到尽头时换到上一行末 / 下一行首（文本行视为单格）
    function moveLeft() {
        if (rows.length === 0)
            return
        const row = rows[currentRow]
        if (row && row.type === "images" && currentCol > 0) {
            currentCol--
            return
        }
        if (currentRow <= 0)
            return
        currentRow--
        const prev = rows[currentRow]
        currentCol = (prev && prev.type === "images")
            ? prev.entries.length - 1
            : 0
    }

    function moveRight() {
        if (rows.length === 0)
            return
        const row = rows[currentRow]
        if (row && row.type === "images" && currentCol < row.entries.length - 1) {
            currentCol++
            return
        }
        if (currentRow >= rows.length - 1)
            return
        currentRow++
        currentCol = 0
    }

    function pasteSelected() {
        if (launching)
            return
        const e = selectedEntry()
        if (!e)
            return
        Clipboard.paste(e.id, e.mime)
        launching = true
        launchRow = currentRow
        launchCol = (currentRow >= 0 && currentRow < rows.length && rows[currentRow].type === "images")
            ? Math.min(currentCol, rows[currentRow].entries.length - 1)
            : 0
        exitTimer.restart()
    }

    function reset() {
        animEnabled = false
        launching = false
        launchRow = -1
        launchCol = -1
        currentRow = 0
        currentCol = 0
        if (searchInput.text !== "")
            searchInput.text = ""
        Clipboard.search("")
        Clipboard.refresh()
        searchInput.forceActiveFocus()
        Qt.callLater(function() { root.animEnabled = true })
    }

    Timer {
        id: exitTimer
        interval: root.launchAnimMs
        repeat: false
        onTriggered: root.closeRequested()
    }

    Connections {
        target: Clipboard
        function onFilteredChanged() { root.buildRows() }
    }

    onWidthChanged: buildRows()
    Component.onCompleted: buildRows()

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.searchHeight
            radius: Size.rounding.full
            color: Color.withAlpha(Color.surfaceContainerHighest, 0.45)

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
                    Keys.priority: Keys.BeforeItem

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "搜索剪贴板..."
                        color: Color.textMuted
                        font.pixelSize: Size.fontSize.lg
                        visible: searchInput.text.length === 0 && !searchInput.activeFocus
                    }

                    onTextChanged: Clipboard.search(text)
                    Keys.onPressed: (event) => {
                        if (root.launching) {
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.pasteSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.moveUp()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            root.moveDown()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            root.moveLeft()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            root.moveRight()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeRequested()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    text: (Clipboard.filtered ? Clipboard.filtered.length : 0) + " 条"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.xsm
                    visible: Clipboard.filtered && Clipboard.filtered.length > 0
                }

                Text {
                    text: "delete"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.sm
                    color: Color.textMuted

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: !root.launching
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clipboard.clear()
                    }
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            reuseItems: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.currentRow
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Size.anim.durFast
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: root.navInset
            preferredHighlightEnd: height - root.textRowHeight - root.navInset
            highlight: Item {}

            delegate: Item {
                id: rowItem
                width: ListView.view ? ListView.view.width : 0
                height: modelData.type === "images"
                    ? root.imageCellH + root.navInset * 2
                    : root.textRowHeight + root.navInset

                readonly property int rowIndex: index
                readonly property bool isCurrentRow: index === root.currentRow
                readonly property bool rowChosen: root.launching && index === root.launchRow
                readonly property bool rowExiting: root.launching && index !== root.launchRow

                opacity: rowExiting ? 0 : 1
                x: rowExiting ? root.exitSlide : 0

                Behavior on opacity {
                    enabled: root.animEnabled
                    Anim { type: Anim.Exit }
                }
                Behavior on x {
                    enabled: root.animEnabled
                    Anim { type: Anim.Exit }
                }

                Loader {
                    x: root.navInset
                    y: root.navInset / 2
                    width: parent.width - root.navInset * 2
                    height: root.textRowHeight
                    active: modelData.type === "text"
                    visible: active
                    sourceComponent: textRowComp
                }

                Loader {
                    x: root.navInset
                    y: root.navInset
                    width: parent.width - root.navInset * 2
                    height: root.imageCellH
                    active: modelData.type === "images"
                    visible: active
                    sourceComponent: imageRowComp
                }

                Component {
                    id: textRowComp
                    Rectangle {
                        anchors.fill: parent
                        radius: Size.rounding.md
                        color: rowItem.isCurrentRow ? Color.primary : Color.withAlpha(Color.surfaceContainerHighest, 0.35)
                        scale: rowItem.isCurrentRow && !root.launching ? 1.008 : 1.0
                        transformOrigin: Item.Center

                        Behavior on color {
                            enabled: root.animEnabled
                            CAnim {}
                        }
                        Behavior on scale {
                            enabled: root.animEnabled
                            Anim { type: Anim.EffectsFast }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.launching
                            onClicked: {
                                root.currentRow = rowItem.rowIndex
                                root.currentCol = 0
                                root.pasteSelected()
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            text: (modelData.entries[0] && modelData.entries[0].preview) || ""
                            color: rowItem.isCurrentRow ? Color.primaryText : Color.text
                            font.pixelSize: Size.fontSize.md
                            font.family: Size.fontSans

                            Behavior on color {
                                enabled: root.animEnabled
                                CAnim {}
                            }
                        }
                    }
                }

                Component {
                    id: imageRowComp
                    Row {
                        spacing: root.cellSpacing

                        Repeater {
                            model: modelData.entries

                            delegate: Rectangle {
                                id: cell
                                width: root.imageCellW
                                height: root.imageCellH
                                radius: Size.rounding.md
                                color: Color.withAlpha(Color.surfaceContainerHighest, 0.35)
                                scale: cell.cellCurrent && !root.launching ? 1.06 : 1.0
                                transformOrigin: Item.Center

                                readonly property bool cellCurrent: rowItem.isCurrentRow && index === root.currentCol
                                readonly property bool cellFade: rowItem.rowChosen && index !== root.launchCol

                                opacity: cellFade ? 0 : 1
                                Behavior on opacity {
                                    enabled: root.animEnabled
                                    Anim { type: Anim.Exit }
                                }
                                Behavior on scale {
                                    enabled: root.animEnabled
                                    Anim { type: Anim.EffectsFast }
                                }

                                layer.enabled: thumbImg.status === Image.Ready
                                layer.smooth: true
                                layer.effect: OpacityMask {
                                    maskSource: Item {
                                        width: cell.width
                                        height: cell.height
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: cell.radius
                                            color: "#000000"
                                        }
                                    }
                                }

                                Image {
                                    id: thumbImg
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    // 原比例完整可见；cell 底色做 letterbox
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    smooth: true
                                    mipmap: true
                                    source: modelData.thumb ? ("file://" + modelData.thumb) : ""
                                    // 2× 解码，避免 HiDPI / 缩放发糊（磁盘 thumb 长边 ≤384）
                                    sourceSize.width: root.imageCellW * 2
                                    sourceSize.height: root.imageCellH * 2
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !modelData.thumb || thumbImg.status !== Image.Ready
                                    text: "\uf03e"
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.xl
                                    color: Color.textMuted
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: cell.radius
                                    border.width: 3
                                    border.color: Color.primary
                                    opacity: cell.cellCurrent ? 1 : 0

                                    Behavior on opacity {
                                        enabled: root.animEnabled
                                        Anim { type: Anim.EffectsFast }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !root.launching
                                    onClicked: {
                                        root.currentRow = rowItem.rowIndex
                                        root.currentCol = index
                                        root.pasteSelected()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
