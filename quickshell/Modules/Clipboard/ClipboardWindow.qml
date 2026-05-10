import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Clavis.Clipboard
import qs.config

PanelWindow {
    id: root

    visible: false
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "clipboard-overlay"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // 后端模型：最新 50 条（搜索时为过滤后的结果）
    readonly property var entries: ClipboardStore.recentEntries
    property var rows: []
    property int selectedGlobalIndex: 0
    property bool expandedTextMode: false
    property int rowRenderLimit: 0
    property string searchQuery: ""

    property int imageColumns: {
        const usable = Math.max(360, windowCard.width - 80);
        const targetCell = 180;
        return Math.max(2, Math.min(6, Math.floor((usable + 12) / (targetCell + 12))));
    }

    function openWindow()  { visible = true; }
    function closeWindow() { visible = false; }
    function toggleWindow(){ visible = !visible; }

    function totalItems() {
        let count = 0;
        for (let i = 0; i < rows.length; i++) count += rows[i].items.length;
        return count;
    }

    function globalIndexFor(rowIndex, colIndex) {
        let idx = 0;
        for (let i = 0; i < rowIndex; i++) idx += rows[i].items.length;
        return idx + colIndex;
    }

    function locateGlobalIndex(globalIndex) {
        let left = globalIndex;
        for (let r = 0; r < rows.length; r++) {
            const rowCount = rows[r].items.length;
            if (left < rowCount) return { row: r, col: left };
            left -= rowCount;
        }
        return { row: 0, col: 0 };
    }

    function clampSelected() {
        const total = totalItems();
        if (total <= 0) { selectedGlobalIndex = 0; return; }
        selectedGlobalIndex = Math.max(0, Math.min(selectedGlobalIndex, total - 1));
    }

    function moveHorizontal(step) {
        if (rows.length === 0) return;
        const pos = locateGlobalIndex(selectedGlobalIndex);
        const row = rows[pos.row];
        if (row.type !== "images") return;
        const nextCol = Math.max(0, Math.min(pos.col + step, row.items.length - 1));
        selectedGlobalIndex = globalIndexFor(pos.row, nextCol);
    }

    function moveVertical(step) {
        if (rows.length === 0) return;
        const pos = locateGlobalIndex(selectedGlobalIndex);
        let targetRow = pos.row + step;
        while (targetRow >= 0 && targetRow < rows.length) {
            if (rows[targetRow].items.length > 0) break;
            targetRow += step;
        }
        if (targetRow < 0 || targetRow >= rows.length) return;
        const targetCol = Math.max(0, Math.min(pos.col, rows[targetRow].items.length - 1));
        selectedGlobalIndex = globalIndexFor(targetRow, targetCol);
    }

    // 把模型按 image / text / unknown 分行；image 行按列数切块
    function rebuildRows() {
        const nextRows = [];
        let pendingImages = [];

        function flushImages() {
            if (pendingImages.length > 0) {
                const chunkSize = Math.max(1, imageColumns);
                for (let start = 0; start < pendingImages.length; start += chunkSize) {
                    nextRows.push({ type: "images", items: pendingImages.slice(start, start + chunkSize) });
                }
                pendingImages = [];
            }
        }

        const total = entries.count();
        for (let i = 0; i < total; i++) {
            const it = entries.get(i);
            if (it.kind === "image") {
                pendingImages.push(it);
            } else if (it.kind === "unknown") {
                flushImages();
                nextRows.push({ type: "unknown", items: [it] });
            } else {
                flushImages();
                nextRows.push({ type: "text", items: [it] });
            }
        }
        flushImages();

        rows = nextRows;
        if (rowRenderLimit <= 0 || rowRenderLimit > rows.length) {
            rowRenderLimit = Math.min(rows.length, 24);
        }
        if (rowRenderLimit < rows.length && !lazyRowsTimer.running) lazyRowsTimer.start();
        clampSelected();
    }

    function ensureSelectedVisible() {
        if (!visible || rows.length === 0) return;
        const pos = locateGlobalIndex(selectedGlobalIndex);
        if (pos.row < 0 || pos.row >= rows.length) return;
        rowsList.positionViewAtIndex(pos.row, ListView.Contain);
    }

    function selectedItem() {
        if (rows.length === 0) return null;
        const pos = locateGlobalIndex(selectedGlobalIndex);
        if (pos.row < 0 || pos.row >= rows.length) return null;
        const row = rows[pos.row];
        if (!row || pos.col < 0 || pos.col >= row.items.length) return null;
        return row.items[pos.col];
    }

    function selectedIsText() {
        const it = selectedItem();
        return !!it && it.kind === "text";
    }

    function selectedExpandedText() {
        const it = selectedItem();
        if (!it) return "";
        return it.preview || "";
    }

    function toggleExpandedText() {
        if (!selectedIsText()) return;
        expandedTextMode = !expandedTextMode;
        if (expandedTextMode && expandedTextScroll.contentItem) {
            expandedTextScroll.contentItem.contentY = 0;
        }
    }

    function scrollExpandedText(step) {
        if (!expandedTextMode || !expandedTextScroll.contentItem) return false;
        const content = expandedTextScroll.contentItem;
        const lineStep = Math.max(20, expandedTextBody.font.pixelSize * 1.8);
        const nextY = content.contentY + step * lineStep;
        const maxY = Math.max(0, content.contentHeight - expandedTextScroll.height);
        content.contentY = Math.max(0, Math.min(nextY, maxY));
        return true;
    }

    function clearClipboardHistory() {
        ClipboardStore.clearAll();
        selectedGlobalIndex = 0;
        expandedTextMode = false;
    }

    function applySelectedItem() {
        const it = selectedItem();
        if (!it) return;
        ClipboardStore.pasteEntry(it.entryId);
        expandedTextMode = false;
        root.closeWindow();
    }

    function scheduleRebuildRows() {
        if (!rebuildTimer.running) rebuildTimer.start();
    }

    Connections {
        target: ClipboardStore
        function onEntriesChanged() { root.scheduleRebuildRows(); }
    }

    Timer {
        id: rebuildTimer
        interval: 16
        repeat: false
        onTriggered: root.rebuildRows()
    }

    Timer {
        id: lazyRowsTimer
        interval: 8
        repeat: true
        onTriggered: {
            if (root.rowRenderLimit >= root.rows.length) { stop(); return; }
            root.rowRenderLimit = Math.min(root.rows.length, root.rowRenderLimit + 24);
        }
    }

    onVisibleChanged: {
        if (visible) {
            searchQuery = "";
            ClipboardStore.searchKeyword = "";
            ClipboardStore.refresh();
            scheduleRebuildRows();
            selectedGlobalIndex = 0;
            expandedTextMode = false;
            searchField.forceActiveFocus();
        }
    }

    onSearchQueryChanged: {
        ClipboardStore.searchKeyword = searchQuery;
        selectedGlobalIndex = 0;
        expandedTextMode = false;
    }

    onSelectedGlobalIndexChanged: {
        if (expandedTextMode && !selectedIsText()) expandedTextMode = false;
        Qt.callLater(ensureSelectedVisible);
    }
    onRowsChanged: {
        if (expandedTextMode && !selectedIsText()) expandedTextMode = false;
    }
    onImageColumnsChanged: rebuildRows()

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeWindow()
    }

    Rectangle {
        id: windowCard
        width: 1008
        height: 567
        anchors.centerIn: parent
        radius: 20
        color: Qt.rgba(Colorscheme.surface_container.r, Colorscheme.surface_container.g, Colorscheme.surface_container.b, 0.92)
        border.color: Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.35)
        border.width: 1
        clip: true
        focus: true

        Keys.onEscapePressed: event => {
            if (expandedTextMode) { expandedTextMode = false; event.accepted = true; return; }
            if (root.searchQuery.length > 0) { root.searchQuery = ""; event.accepted = true; return; }
            root.closeWindow();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Backspace || event.key === Qt.Key_K)) {
                root.clearClipboardHistory();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: Sizes.spacing.md

            RowLayout {
                Layout.fillWidth: true
                spacing: Sizes.spacing.md

                Text {
                    text: "剪贴板"
                    font.pixelSize: 22
                    font.bold: true
                    color: Colorscheme.on_surface
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Sizes.rounding.normal
                    color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.7)
                    border.width: searchField.activeFocus ? 1 : 0
                    border.color: Colorscheme.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            text: "search"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Sizes.font.lg
                            color: Colorscheme.on_surface_variant
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "搜索剪贴板…"
                            color: Colorscheme.on_surface
                            placeholderTextColor: Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.7)
                            font.pixelSize: Sizes.font.lg
                            background: null
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            text: root.searchQuery
                            onTextChanged: if (text !== root.searchQuery) root.searchQuery = text

                            Keys.onUpPressed: event => {
                                if (!root.scrollExpandedText(-1)) root.moveVertical(-1);
                                event.accepted = true;
                            }
                            Keys.onDownPressed: event => {
                                if (!root.scrollExpandedText(1)) root.moveVertical(1);
                                event.accepted = true;
                            }
                            Keys.onLeftPressed: event => {
                                if (text.length === 0) { root.moveHorizontal(-1); event.accepted = true; }
                            }
                            Keys.onRightPressed: event => {
                                if (text.length === 0) { root.moveHorizontal(1); event.accepted = true; }
                            }
                            Keys.onReturnPressed: event => { root.applySelectedItem(); event.accepted = true; }
                            Keys.onEnterPressed:  event => { root.applySelectedItem(); event.accepted = true; }
                            Keys.onPressed: event => {
                                if ((event.modifiers & Qt.ControlModifier)
                                    && (event.key === Qt.Key_Backspace || event.key === Qt.Key_K)) {
                                    root.clearClipboardHistory();
                                    event.accepted = true;
                                    return;
                                }
                                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    if (root.selectedIsText()) {
                                        root.toggleExpandedText();
                                        event.accepted = true;
                                    } else {
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.searchQuery.length > 0
                            text: "(" + root.totalItems() + ")"
                            font.pixelSize: Sizes.font.md
                            color: Colorscheme.on_surface_variant
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Text {
                    text: "Tab 展开 · Ctrl + BackSpace 清空 · Esc 关闭"
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface_variant
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(Colorscheme.outline_variant.r, Colorscheme.outline_variant.g, Colorscheme.outline_variant.b, 0.5)
            }

            Rectangle {
                visible: root.expandedTextMode
                Layout.fillWidth: true
                Layout.preferredHeight: root.expandedTextMode ? 200 : 0
                radius: Sizes.rounding.normal
                clip: true
                color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.72)
                border.width: 1
                border.color: Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.35)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: Sizes.spacing.sm

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "文本展开阅读"
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            color: Colorscheme.on_surface
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Tab收起 · ↑↓细滚"
                            font.pixelSize: Sizes.font.sm
                            color: Colorscheme.on_surface_variant
                        }
                    }

                    ScrollView {
                        id: expandedTextScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Text {
                            id: expandedTextBody
                            width: expandedTextScroll.width - 12
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            text: root.selectedExpandedText()
                            color: Colorscheme.on_surface
                            font.pixelSize: Sizes.font.lg
                            lineHeight: 1.35
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: rowsList
                    anchors.fill: parent
                    visible: root.rows.length > 0
                    clip: true
                    spacing: 14
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.rowRenderLimit

                    delegate: Item {
                        id: rowDelegate
                        required property int index
                        readonly property var modelData: root.rows[index]
                        width: rowsList.width
                        height: (modelData.type === "text" || modelData.type === "unknown") ? 54 : imageRow.implicitHeight

                        Rectangle {
                            visible: modelData.type === "text"
                            anchors.fill: parent
                            radius: Sizes.rounding.normal
                            readonly property int gidx: root.globalIndexFor(index, 0)
                            color: root.selectedGlobalIndex === gidx
                                ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.75)
                                : Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.5)
                            border.width: root.selectedGlobalIndex === gidx ? 1 : 0
                            border.color: Colorscheme.primary

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.items[0].preview || "(空文本)"
                                color: root.selectedGlobalIndex === parent.gidx ? Colorscheme.on_primary_container : Colorscheme.on_surface
                                font.pixelSize: Sizes.font.lg
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedGlobalIndex = parent.gidx;
                                    root.applySelectedItem();
                                }
                            }
                        }

                        Rectangle {
                            visible: modelData.type === "unknown"
                            anchors.fill: parent
                            radius: Sizes.rounding.normal
                            readonly property int gidx: root.globalIndexFor(index, 0)
                            color: root.selectedGlobalIndex === gidx
                                ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.55)
                                : Qt.rgba(Colorscheme.surface_container_highest.r, Colorscheme.surface_container_highest.g, Colorscheme.surface_container_highest.b, 0.4)
                            border.width: 1
                            border.color: root.selectedGlobalIndex === gidx
                                ? Colorscheme.primary
                                : Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.4)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: "help_outline"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: Sizes.font.lg
                                    color: Colorscheme.on_surface_variant
                                }

                                Text {
                                    Layout.fillWidth: true
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.items[0].preview || "(无法识别的内容)"
                                    color: Colorscheme.on_surface_variant
                                    font.pixelSize: Sizes.font.md
                                    font.italic: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selectedGlobalIndex = parent.gidx;
                                    root.applySelectedItem();
                                }
                            }
                        }

                        Row {
                            id: imageRow
                            visible: modelData.type === "images"
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Sizes.spacing.md
                            readonly property int itemCount: Math.max(1, modelData.items.length)
                            readonly property real rawCell: (rowDelegate.width - (spacing * (itemCount - 1))) / itemCount
                            readonly property int cellWidth: Math.max(120, Math.min(220, Math.floor(rawCell)))
                            readonly property int cellHeight: Math.round(cellWidth * 0.66)

                            Repeater {
                                model: modelData.items
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    width: imageRow.cellWidth
                                    height: imageRow.cellHeight
                                    radius: 10
                                    readonly property int gidx: root.globalIndexFor(rowDelegate.index, index)
                                    color: Qt.rgba(Colorscheme.surface_container_highest.r, Colorscheme.surface_container_highest.g, Colorscheme.surface_container_highest.b, 0.7)
                                    border.width: root.selectedGlobalIndex === gidx ? 2 : 0
                                    border.color: Colorscheme.primary

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: modelData.thumbUrl || ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        cache: true
                                        asynchronous: true
                                        sourceSize.width: imageRow.cellWidth * 2
                                        sourceSize.height: imageRow.cellHeight * 2
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.selectedGlobalIndex = parent.gidx;
                                            root.applySelectedItem();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.rows.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        width: Math.min(parent.width - 40, 560)

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            text: root.searchQuery.length > 0 ? "没有匹配的条目" : "剪贴板当前为空"
                            font.pixelSize: Sizes.font.title
                            font.bold: true
                            color: Colorscheme.on_surface
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            text: root.searchQuery.length > 0
                                ? "换个关键词试试，或按 Esc 清除搜索。"
                                : "先复制任意文本或图片后，按 Super+Z 再打开即可看到历史。"
                            font.pixelSize: Sizes.font.lg
                            color: Colorscheme.on_surface_variant
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            visible: root.searchQuery.length === 0
                            text: "快捷操作：Tab 展开文本、↑↓ 细滚、Enter 复制、Ctrl+Backspace 清空。"
                            font.pixelSize: Sizes.font.md
                            color: Colorscheme.on_surface_variant
                        }
                    }
                }
            }
        }

        MouseArea { anchors.fill: parent }
    }
}
