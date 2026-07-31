// Rightbar — 右侧设置栏壳（Super+V）
// 单 Loader：任一时刻只有一页；Tab 切换 = 旧页右滑淡出 → 换页 → 新页滑入
// 开栏全屏 mask：点空白关闭；关栏 mask=0
// 无 gooey；关窗后 Loader.active=false，页面销毁
//
// 性能：
//   - 壳常驻，页面按需创建/销毁
//   - 切换动画串行，禁止双 Loader 交叉淡化
//   - 占位页不碰 Network/Bluetooth 扫描

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Components
import qs.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: contentActive

    // 开栏铺满，点空白关闭；关栏 mask=0
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    readonly property int panelWidth: 380
    readonly property int panelHeight: 560
    readonly property int closedOffset: panelWidth + 48
    readonly property bool contentActive: open || panelSlide !== closedOffset

    exclusiveZone: 0

    WlrLayershell.namespace: "qsl-rightbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property bool open: false
    property string view: "network"
    property string pendingView: ""
    property int panelSlide: closedOffset

    readonly property var views: ["network", "bluetooth", "audio", "updates"]
    readonly property var viewMeta: ({
        network:   { title: "网络", icon: "\uf1eb" },
        bluetooth: { title: "蓝牙", icon: "\uf293" },
        audio:     { title: "声音", icon: "\uf028" },
        updates:   { title: "更新", icon: "\uf019" }
    })

    function normalizeView(v) {
        if (!v)
            return views[0]
        const key = String(v).toLowerCase()
        for (let i = 0; i < views.length; i++) {
            if (views[i] === key)
                return views[i]
        }
        return views[0]
    }

    function titleOf(v) {
        const m = viewMeta[v]
        return m ? m.title : v
    }

    function iconOf(v) {
        const m = viewMeta[v]
        return m ? m.icon : ""
    }

    function toggle() {
        open ? closeWindow() : openWindow()
    }

    function openWindow(v) {
        if (v !== undefined && v !== null && String(v).length > 0)
            view = normalizeView(v)
        if (!open)
            Island.captureFocus()
        open = true
    }

    function closeWindow() {
        if (!open)
            return
        open = false
        Island.restoreFocus()
    }

    // 与旧 IPC 对齐：指定页打开；同页再开则关闭
    function openView(v) {
        const target = normalizeView(v)
        if (open && view === target) {
            closeWindow()
            return
        }
        if (open)
            switchTo(target)
        else {
            Island.captureFocus()
            view = target
            open = true
        }
    }

    function next() { cycle(1) }
    function prev() { cycle(-1) }

    function cycle(step) {
        const i = views.indexOf(view)
        const idx = i < 0 ? 0 : i
        const n = views[(idx + step + views.length) % views.length]
        if (open)
            switchTo(n)
        else {
            Island.captureFocus()
            view = n
            open = true
        }
    }

    function switchTo(nextView) {
        const target = normalizeView(nextView)
        if (target === view)
            return
        if (!open) {
            view = target
            open = true
            return
        }
        // 对齐 Hub：直接切页，无淡出/滑入
        view = target
    }

    // 面板滑入/滑出
    onOpenChanged: {
        panelAnim.stop()
        if (open) {
            panelAnim.duration = 420
            panelAnim.easing.type = Easing.OutBack
            panelAnim.easing.overshoot = 0.25
            panelAnim.to = 0
        } else {
            panelAnim.duration = 280
            panelAnim.easing.type = Easing.InBack
            panelAnim.easing.overshoot = 0.08
            panelAnim.to = closedOffset
        }
        panelAnim.start()
    }

    NumberAnimation {
        id: panelAnim
        target: root
        property: "panelSlide"
    }

    onContentActiveChanged: {
        if (!contentActive)
            pendingView = ""
    }

    Item {
        id: inputMask
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMask }

    FocusScope {
        anchors.fill: parent
        enabled: root.open
        focus: root.open
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.closeWindow()
                event.accepted = true
                return
            }
            // Shift+Tab 在 Qt 里通常是 Key_Backtab，不是带 Shift 的 Key_Tab
            if (event.key === Qt.Key_Backtab) {
                root.cycle(-1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Tab) {
                root.cycle((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeWindow()
        }

        Rectangle {
            id: card
            width: root.panelWidth
            height: root.panelHeight
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 12 - root.panelSlide
            anchors.topMargin: 56
            visible: root.contentActive
            radius: Size.rounding.xl
            // 对齐 Hub：实色 background，去半透明
            color: Color.background
            border.width: 2
            border.color: Color.secondaryFixed
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Size.spacing.lg
                spacing: Size.spacing.md

                // Hub 式 Tab：固定高度，不吃 fillHeight
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Size.island.hubTabBarHeight * 0.7
                    Layout.maximumHeight: Size.island.hubTabBarHeight * 0.7
                    spacing: Size.island.hubTabSpacing

                    Repeater {
                        model: root.views

                        QslHubTab {
                            required property string modelData
                            text: root.titleOf(modelData)
                            icon: root.iconOf(modelData)
                            selected: modelData === root.view
                            onClicked: root.switchTo(modelData)
                        }
                    }
                }

                // 单页舞台
                Item {
                    id: pageHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        active: root.contentActive
                        sourceComponent: {
                            switch (root.view) {
                            case "bluetooth": return btPage
                            case "audio": return audioPage
                            case "updates": return updatesPage
                            default: return networkPage
                            }
                        }

                        Connections {
                            target: pageLoader.item
                            ignoreUnknownSignals: true
                            function onRequestClose() { root.closeWindow() }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: networkPage
        NetworkPage {}
    }
    Component {
        id: btPage
        BluetoothPage {}
    }
    Component {
        id: audioPage
        AudioPage {}
    }
    Component {
        id: updatesPage
        UpdatesPage {}
    }
}
