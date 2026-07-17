// Rightbar — 右侧设置栏壳（Super+V）
// 单 Loader：任一时刻只有一页；Tab 切换 = 旧页右滑淡出 → 换页 → 新页滑入
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
import qs.data.state

PanelWindow {
    id: root

    color: "transparent"
    visible: true

    anchors {
        right: true
        top: true
    }

    readonly property int panelWidth: 380
    readonly property int panelHeight: 560
    readonly property int closedOffset: panelWidth + 48
    readonly property bool contentActive: open || panelSlide !== closedOffset

    implicitWidth: panelWidth + 24
    implicitHeight: panelHeight + 80
    exclusiveZone: 0

    WlrLayershell.namespace: "qsl-rightbar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property bool open: false
    property bool switching: false
    property string view: "network"
    property string pendingView: ""
    property int panelSlide: closedOffset

    readonly property var views: ["network", "bluetooth", "audio", "updates"]
    readonly property var viewMeta: ({
        network:   { title: "网络",   icon: "\uf1eb" },
        bluetooth: { title: "蓝牙",   icon: "\uf293" },
        audio:     { title: "声音",   icon: "\uf028" },
        updates:   { title: "更新",   icon: "\uf062" }
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
        open = true
    }

    function closeWindow() {
        if (!open)
            return
        open = false
    }

    // 与旧 IPC 对齐：指定页打开；同页再开则关闭
    function openView(v) {
        const target = normalizeView(v)
        if (open && view === target && !switching) {
            closeWindow()
            return
        }
        if (open)
            switchTo(target)
        else {
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
            view = n
            open = true
        }
    }

    function switchTo(nextView) {
        const target = normalizeView(nextView)
        if (target === view || switching)
            return
        if (!open) {
            view = target
            open = true
            return
        }
        switching = true
        pendingView = target
        pageExit.start()
    }

    // 面板滑入/滑出
    onOpenChanged: {
        panelAnim.stop()
        if (open) {
            pageHost.fade = 1
            pageHost.slide = 0
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

    // 页切换：旧页右滑淡出 → 换 source → 新页从左侧滑入
    SequentialAnimation {
        id: pageExit
        ParallelAnimation {
            NumberAnimation {
                target: pageHost
                property: "fade"
                to: 0
                duration: Size.anim.fast
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: pageHost
                property: "slide"
                to: 36
                duration: Size.anim.fast
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                root.view = root.pendingView
                pageHost.slide = -24
                pageHost.fade = 0
                pageEnter.start()
            }
        }
    }

    ParallelAnimation {
        id: pageEnter
        NumberAnimation {
            target: pageHost
            property: "fade"
            to: 1
            duration: Size.anim.normal
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageHost
            property: "slide"
            to: 0
            duration: Size.anim.smooth
            easing.type: Easing.OutCubic
        }
        onFinished: root.switching = false
    }

    onContentActiveChanged: {
        if (!contentActive) {
            switching = false
            pendingView = ""
            pageHost.fade = 1
            pageHost.slide = 0
        }
    }

    Item {
        id: inputMask
        x: root.open ? (root.width - root.panelWidth - 12) : root.width
        y: 56
        width: root.open ? root.panelWidth : 0
        height: root.open ? root.panelHeight : 0
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
            color: Color.withAlpha(Color.surfaceHigh, 0.97)
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

                // Tab 条即导航，无标题 / 无关闭按钮（Esc 或点外侧关）
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.xs

                    Repeater {
                        model: root.views

                        Rectangle {
                            id: tab
                            required property string modelData
                            readonly property bool selected: modelData === root.view

                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Size.rounding.full
                            color: selected
                                ? Color.withAlpha(Color.primary, 0.18)
                                : (tabMa.containsMouse
                                    ? Color.withAlpha(Color.text, 0.06)
                                    : "transparent")

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.iconOf(tab.modelData)
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.sm
                                    color: tab.selected ? Color.primary : Color.textMuted
                                }
                                Text {
                                    text: root.titleOf(tab.modelData)
                                    font.pixelSize: Size.fontSize.sm
                                    font.bold: tab.selected
                                    color: tab.selected ? Color.primary : Color.textMuted
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.switching
                                onClicked: root.switchTo(tab.modelData)
                            }
                        }
                    }
                }

                // 单页舞台
                Item {
                    id: pageHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    property real fade: 1
                    property real slide: 0

                    opacity: fade

                    Loader {
                        id: pageLoader
                        width: parent.width
                        height: parent.height
                        x: pageHost.slide
                        active: root.contentActive
                        sourceComponent: {
                            switch (root.view) {
                            case "bluetooth": return btPage
                            case "audio": return audioPage
                            case "updates": return updatesPage
                            default: return networkPage
                            }
                        }

                        // 页面请求关闭面板（如打开 nmtui）
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
        PlaceholderPage {
            viewId: "bluetooth"
            hint: "设备扫描、配对与连接将接 Bluetooth service。"
        }
    }
    Component {
        id: audioPage
        PlaceholderPage {
            viewId: "audio"
            hint: "输出 / 输入音量与静音将接 Volume service。"
        }
    }
    Component {
        id: updatesPage
        PlaceholderPage {
            viewId: "updates"
            hint: "包列表按需拉取；打开本页或手动刷新时才检查更新。"
        }
    }
}
