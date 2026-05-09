import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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

    property var entries: []
    property var rows: []
    property int selectedGlobalIndex: 0
    property string jsonBuffer: ""
    property bool expandedTextMode: false
    property bool loading: false
    property int rowRenderLimit: 0
    property string searchQuery: ""

    // 过滤后的条目：文本按 text / preview / full_text 子串匹配，
    // 图片按 label 匹配；空查询直接透传。case-insensitive。
    readonly property var filteredEntries: {
        const q = searchQuery.trim().toLowerCase();
        if (q.length === 0) return entries;
        const out = [];
        for (let i = 0; i < entries.length; i++) {
            const it = entries[i];
            let hay = "";
            if (it.kind === "image") {
                hay = (it.label || "") + " " + (it.mime || "");
            } else if (it.kind === "unknown") {
                hay = (it.preview || "");
            } else {
                hay = (it.full_text || "") + " " + (it.text || "") + " " + (it.preview || "");
            }
            if (hay.toLowerCase().indexOf(q) !== -1) out.push(it);
        }
        return out;
    }
    property int imageColumns: {
        const usable = Math.max(360, windowCard.width - 80);
        const targetCell = 180;
        return Math.max(2, Math.min(6, Math.floor((usable + 12) / (targetCell + 12))));
    }

    function openWindow() {
        visible = true;
    }

    function closeWindow() {
        visible = false;
    }

    function toggleWindow() {
        visible = !visible;
    }

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
        if (total <= 0) {
            selectedGlobalIndex = 0;
            return;
        }
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

    function rebuildRows() {
        const nextRows = [];
        let pendingImages = [];
        const source = filteredEntries;

        function flushImages() {
            if (pendingImages.length > 0) {
                const chunkSize = Math.max(1, imageColumns);
                for (let start = 0; start < pendingImages.length; start += chunkSize) {
                    nextRows.push({ type: "images", items: pendingImages.slice(start, start + chunkSize) });
                }
                pendingImages = [];
            }
        }

        for (let i = 0; i < source.length; i++) {
            const item = source[i];
            if (item.kind === "image") {
                pendingImages.push(item);
            } else if (item.kind === "unknown") {
                flushImages();
                nextRows.push({ type: "unknown", items: [item] });
            } else {
                flushImages();
                nextRows.push({ type: "text", items: [item] });
            }
        }
        flushImages();

        rows = nextRows;
        if (rowRenderLimit <= 0 || rowRenderLimit > rows.length) {
            rowRenderLimit = Math.min(rows.length, 24);
        }
        if (rowRenderLimit < rows.length && !lazyRowsTimer.running) {
            lazyRowsTimer.start();
        }
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
        const item = selectedItem();
        return !!item && item.kind === "text";
    }

    function selectedExpandedText() {
        const item = selectedItem();
        if (!item) return "";
        return item.full_text || item.text || item.preview || "";
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
        Quickshell.execDetached(["bash", "-lc", "cliphist wipe >/dev/null 2>&1"]);
        entries = [];
        rows = [];
        selectedGlobalIndex = 0;
        expandedTextMode = false;
    }

    function applySelectedItem() {
        if (rows.length === 0) return;
        const pos = locateGlobalIndex(selectedGlobalIndex);
        const item = rows[pos.row].items[pos.col];
        if (!item || !item.raw_b64) return;

        const safeB64 = item.raw_b64.replace(/'/g, "'\\''");
        // 使用脚本提供的「剪贴板原始 mime」（paste_mime）回填 wl-copy。
        // 关键区分：
        //   - 真二进制图片：paste_mime = image/png 等 → wl-copy --type image/png
        //   - QQ 等 HTML 富文本图片：paste_mime = text/html → 必须以 HTML 回填
        //     若误用 image/png 回填，QQ 会把 HTML 字节当作文件流，识别为「发送文件」
        //   - 纯文本：paste_mime = text/plain
        // -n 抑制 wl-copy 在 text 模式下额外追加换行
        let wlcopy = "wl-copy -n";
        const pasteMime = item.paste_mime || item.mime || "";
        const safeMime = String(pasteMime).replace(/[^A-Za-z0-9/.+-]/g, "");
        if (safeMime.length > 0) wlcopy = "wl-copy -n --type " + safeMime;
        let cmd = "printf '%s' '" + safeB64 + "' | base64 -d | cliphist decode | " + wlcopy;

        // HTML 图片条目优先使用脚本提供的单行 paste_html，避免多行 html/body 包装带来的前导空行。
        if (safeMime === "text/html" && item.paste_html) {
            const safeHtml = String(item.paste_html).replace(/'/g, "'\\''");
            cmd = "printf '%s' '" + safeHtml + "' | " + wlcopy;
        }
        Quickshell.execDetached(["bash", "-lc", cmd]);
        expandedTextMode = false;
        root.closeWindow();
    }


    function refresh() {
        entries = [];
        rows = [];
        rowRenderLimit = 0;
        jsonBuffer = "";
        loading = true;
        loadProcess.running = false;
        loadProcess.running = true;
    }

    function appendChunk(chunk) {
        const text = (chunk === undefined || chunk === null) ? "" : String(chunk);
        if (text.length === 0) return false;

        let changed = false;
        const parts = text.split('\n');
        for (let i = 0; i < parts.length; i++) {
            const line = parts[i].trim();
            if (line.length === 0) continue;
            try {
                const obj = JSON.parse(line);
                root.entries.push(obj);
                changed = true;
            } catch (e) {
                // Keep unparsed fragments as fallback for onExited.
                root.jsonBuffer += line;
            }
        }

        return changed;
    }

    function scheduleRebuildRows() {
        if (!rebuildTimer.running) rebuildTimer.start();
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
            if (root.rowRenderLimit >= root.rows.length) {
                stop();
                return;
            }
            root.rowRenderLimit = Math.min(root.rows.length, root.rowRenderLimit + 24);
        }
    }

    readonly property string clipboardDumpScriptPath: Qt.resolvedUrl("../../scripts/clipboard_dump.py").toString().replace("file://", "")

    Process {
        id: loadProcess
        command: ["python3", root.clipboardDumpScriptPath, "--limit", "100"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const changed = root.appendChunk(data);
                if (changed) root.scheduleRebuildRows();
            }
        }
        onExited: {
            root.appendChunk(root.jsonBuffer);
            rebuildTimer.stop();
            root.rebuildRows();
            root.jsonBuffer = "";
            root.loading = false;
        }
    }
    onVisibleChanged: {
        if (visible) {
            searchQuery = "";
            refresh();
            selectedGlobalIndex = 0;
            expandedTextMode = false;
            searchField.forceActiveFocus();
        }
    }

    onSearchQueryChanged: {
        selectedGlobalIndex = 0;
        expandedTextMode = false;
        scheduleRebuildRows();
    }

    onSelectedGlobalIndexChanged: {
        if (expandedTextMode && !selectedIsText()) {
            expandedTextMode = false;
        }
        Qt.callLater(ensureSelectedVisible)
    }
    onRowsChanged: {
        if (expandedTextMode && !selectedIsText()) {
            expandedTextMode = false;
        }
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
            if (expandedTextMode) {
                expandedTextMode = false;
                event.accepted = true;
                return;
            }
            if (root.searchQuery.length > 0) {
                root.searchQuery = "";
                event.accepted = true;
                return;
            }
            root.closeWindow();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            // Ctrl+Backspace = 清空历史（会被 TextField 默认捕获，故在 windowCard 之外的截断）
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
                                // 仅在搜索框为空时把左右键当做图片网格导航；否则给 TextField 做光标移动
                                if (text.length === 0) {
                                    root.moveHorizontal(-1);
                                    event.accepted = true;
                                }
                            }
                            Keys.onRightPressed: event => {
                                if (text.length === 0) {
                                    root.moveHorizontal(1);
                                    event.accepted = true;
                                }
                            }
                            Keys.onReturnPressed: event => {
                                root.applySelectedItem();
                                event.accepted = true;
                            }
                            Keys.onEnterPressed: event => {
                                root.applySelectedItem();
                                event.accepted = true;
                            }
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
                    visible: root.rows.length > 0 || root.loading
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

                        // 未知 / 二进制条目：占位条，仍可选中复制原始内容，但不渲染乱码
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
                                        source: modelData.thumb || ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        cache: true
                                        asynchronous: true
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
                    visible: root.loading && root.rows.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        BusyIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: true
                        }

                        Text {
                            text: "正在加载剪贴板历史..."
                            font.pixelSize: Sizes.font.lg
                            color: Colorscheme.on_surface_variant
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.rows.length === 0 && !root.loading

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
