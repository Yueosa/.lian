import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config

Item {
    id: root

    signal closeRequested()

    // —— 数据：按工作区分组 ——
    // 只展示包含至少 1 个窗口的工作区，按 workspace.id 升序。
    // 组内窗口依 address 稳定排序（title 可变会导致顶点跳动）。
    readonly property var groups: {
        const out = []
        const wss = Hyprland.workspaces.values
        const sorted = wss.slice().sort((a, b) => (a && b ? a.id - b.id : 0))
        for (let i = 0; i < sorted.length; ++i) {
            const ws = sorted[i]
            if (!ws || !ws.toplevels) continue
            const wins = ws.toplevels.values.slice().sort((a, b) => {
                const aa = (a && a.address) || ""
                const bb = (b && b.address) || ""
                return aa < bb ? -1 : (aa > bb ? 1 : 0)
            })
            if (!wins || wins.length === 0) continue
            out.push({ ws: ws, wins: wins })
        }
        return out
    }

    // —— 二维焦点：focusGroup=工作区列；focusItem=该列内的窗口行 ——
    property int focusGroup: 0
    property int focusItem: 0

    function clampFocus() {
        if (groups.length === 0) { focusGroup = 0; focusItem = 0; return }
        if (focusGroup < 0) focusGroup = 0
        if (focusGroup >= groups.length) focusGroup = groups.length - 1
        const rows = groups[focusGroup].wins.length
        if (focusItem < 0) focusItem = 0
        if (focusItem >= rows) focusItem = rows - 1
    }

    onGroupsChanged: clampFocus()
    onVisibleChanged: if (visible) {
        // 默认定位到当前活动窗口；找不到则退回当前活动工作区第一个
        const active = Hyprland.activeToplevel
        const focusedWs = Hyprland.focusedWorkspace
        const activeAddr = active ? (active.address || "") : ""
        const wsId = focusedWs ? focusedWs.id : -1
        let g = -1, it = 0
        for (let i = 0; i < groups.length; ++i) {
            const grp = groups[i]
            if (!grp || !grp.ws) continue
            if (activeAddr && grp.wins) {
                for (let j = 0; j < grp.wins.length; ++j) {
                    if (grp.wins[j] && grp.wins[j].address === activeAddr) { g = i; it = j; break }
                }
                if (g >= 0) break
            }
        }
        if (g < 0) {
            for (let i = 0; i < groups.length; ++i) {
                if (groups[i].ws && groups[i].ws.id === wsId) { g = i; break }
            }
            if (g < 0) g = 0
        }
        focusGroup = g
        focusItem = it
        focusGrabber.forceActiveFocus()
    }

    function activateFocused() {
        if (focusGroup < 0 || focusGroup >= groups.length) return
        const grp = groups[focusGroup]
        if (focusItem < 0 || focusItem >= grp.wins.length) return
        const win = grp.wins[focusItem]
        if (!win) return
        const wsId = grp.ws && grp.ws.id
        let addr = win.address || ""
        if (addr.length > 0 && !addr.startsWith("0x")) addr = "0x" + addr
        // 关键：先关 Hub 释放 layer keyboard focus，再延迟 dispatch；
        // 否则 layer 关闭时 Hyprland 会自动把焦点还给"上一个活动窗口"，
        // 把我们 dispatch 的 focuswindow 覆盖掉（视觉上"跳过去又跳回来"）。
        pendingDispatch.wsId = (wsId !== undefined && wsId !== null) ? wsId : -1
        pendingDispatch.addr = addr
        root.closeRequested()
        dispatchTimer.restart()
    }

    QtObject {
        id: pendingDispatch
        property int wsId: -1
        property string addr: ""
    }

    Timer {
        id: dispatchTimer
        interval: 60
        repeat: false
        onTriggered: {
            const cmds = []
            if (pendingDispatch.wsId >= 0) cmds.push("dispatch workspace " + pendingDispatch.wsId)
            if (pendingDispatch.addr.length > 0) cmds.push("dispatch focuswindow address:" + pendingDispatch.addr)
            if (cmds.length === 0) return
            // hyprctl --batch 串行执行，避免两次 IPC 之间被插入焦点还原
            Quickshell.execDetached(["hyprctl", "--batch", cmds.join(" ; ")])
        }
    }

    // —— 专用的键盘抓取点（跨越 Hub Item focus 链）——
    Item {
        id: focusGrabber
        anchors.fill: parent
        focus: root.visible
        Keys.onLeftPressed: (event) => {
            root.focusGroup = Math.max(0, root.focusGroup - 1)
            root.clampFocus()
            event.accepted = true
        }
        Keys.onRightPressed: (event) => {
            root.focusGroup = Math.min(root.groups.length - 1, root.focusGroup + 1)
            root.clampFocus()
            event.accepted = true
        }
        Keys.onUpPressed: (event) => {
            root.focusItem = Math.max(0, root.focusItem - 1)
            event.accepted = true
        }
        Keys.onDownPressed: (event) => {
            const rows = (root.groups[root.focusGroup] && root.groups[root.focusGroup].wins.length) || 0
            root.focusItem = Math.min(rows - 1, root.focusItem + 1)
            event.accepted = true
        }
        Keys.onReturnPressed: (event) => { root.activateFocused(); event.accepted = true }
        Keys.onEnterPressed: (event) => { root.activateFocused(); event.accepted = true }
        Keys.onEscapePressed: (event) => { root.closeRequested(); event.accepted = true }
    }

    // —— 全局快捷键兑底（Hub 子项 focus 链不可靠时也能工作）——
    Shortcut { sequence: "Left";   enabled: root.visible && !focusGrabber.activeFocus; onActivated: { root.focusGroup = Math.max(0, root.focusGroup - 1); root.clampFocus() } }
    Shortcut { sequence: "Right";  enabled: root.visible && !focusGrabber.activeFocus; onActivated: { root.focusGroup = Math.min(root.groups.length - 1, root.focusGroup + 1); root.clampFocus() } }
    Shortcut { sequence: "Up";     enabled: root.visible && !focusGrabber.activeFocus; onActivated: { root.focusItem = Math.max(0, root.focusItem - 1) } }
    Shortcut { sequence: "Down";   enabled: root.visible && !focusGrabber.activeFocus; onActivated: {
        const rows = (root.groups[root.focusGroup] && root.groups[root.focusGroup].wins.length) || 0
        root.focusItem = Math.min(rows - 1, root.focusItem + 1)
    } }
    Shortcut { sequences: ["Return", "Enter"]; enabled: root.visible && !focusGrabber.activeFocus; onActivated: root.activateFocused() }
    Shortcut { sequence: "Escape"; enabled: root.visible && !focusGrabber.activeFocus; onActivated: root.closeRequested() }

    // —— 空态 ——
    Text {
        anchors.centerIn: parent
        visible: groups.length === 0
        text: "没有可切换的窗口"
        color: Colorscheme.on_surface_variant
        font.pixelSize: Sizes.font.xl
    }

    // —— 主体：工作区横向滚动，每个工作区是一列纵向堆叠的窗口 ——
    Flickable {
        id: hFlick
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: groupsRow.implicitWidth
        contentHeight: height
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        visible: groups.length > 0

        ScrollBar.horizontal: ScrollBar {
            policy: hFlick.contentWidth > hFlick.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            height: 6
        }

        // 鼠标滚轮映射到水平滚动
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var dx = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                var step = dx / 120 * 80;
                var nx = hFlick.contentX - step;
                var maxX = Math.max(0, hFlick.contentWidth - hFlick.width);
                hFlick.contentX = Math.max(0, Math.min(maxX, nx));
            }
        }

        // 焦点列变化 → 滚到可见
        Connections {
            target: root
            function onFocusGroupChanged() { Qt.callLater(hFlick._ensureFocusVisible) }
        }
        function _ensureFocusVisible() {
            var g = root.focusGroup;
            if (g < 0 || g >= groupsRow.children.length) return;
            var col = groupsRow.children[g];
            if (!col) return;
            var x0 = col.x;
            var x1 = col.x + col.width;
            if (x0 < contentX) contentX = Math.max(0, x0 - 12);
            else if (x1 > contentX + width) contentX = Math.min(contentWidth - width, x1 - width + 12);
        }

        RowLayout {
            id: groupsRow
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            spacing: Sizes.spacing.l

            Repeater {
                model: root.groups

                ColumnLayout {
                    id: groupCol
                    Layout.fillHeight: true
                    Layout.preferredWidth: 200
                    spacing: Sizes.spacing.sm

                    required property int index
                    required property var modelData

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "工作区 " + (groupCol.modelData.ws.id !== undefined
                                          ? groupCol.modelData.ws.id
                                          : (groupCol.modelData.ws.name || "?"))
                        color: groupCol.index === root.focusGroup ? Colorscheme.on_surface : Colorscheme.on_surface_variant
                        font.pixelSize: Sizes.font.sm
                        font.bold: groupCol.index === root.focusGroup
                    }

                    // 窗口列：纵向滚动
                    Flickable {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        contentWidth: width
                        contentHeight: winsCol.implicitHeight
                        clip: true
                        flickableDirection: Flickable.VerticalFlick

                        ColumnLayout {
                            id: winsCol
                            width: parent.width
                            spacing: Sizes.spacing.sm

                            Repeater {
                                model: groupCol.modelData.wins

                                Item {
                                    id: card
                                    required property int index
                                    required property var modelData
                                    readonly property bool focused: groupCol.index === root.focusGroup
                                                                 && index === root.focusItem

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 124

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Sizes.rounding.normal
                                        color: card.focused
                                            ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.18)
                                            : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                                        border.color: card.focused ? Colorscheme.primary : "transparent"
                                        border.width: 2
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                    }

                                    ScreencopyView {
                                        id: thumb
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        anchors.bottomMargin: 24
                                        captureSource: card.modelData && card.modelData.wayland ? card.modelData.wayland : null
                                        live: true
                                        paintCursor: false
                                        visible: hasContent
                                        smooth: true
                                        // 圆角裁剪 + 插值平滑：将贴图纹理过一层 OpacityMask，
                                        // 避免原始 screencopy 贴边生硬。mask 随 thumb 尺寸反活。
                                        layer.enabled: hasContent
                                        layer.smooth: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: thumb.width
                                                height: thumb.height
                                                radius: Sizes.rounding.normal
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -10
                                        visible: !thumb.hasContent
                                        text: ""
                                        font.family: "Font Awesome 6 Free Solid"
                                        font.pixelSize: Sizes.font.h5
                                        color: Colorscheme.on_surface_variant
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        text: card.modelData ? (card.modelData.title || card.modelData.address || "") : ""
                                        font.pixelSize: Sizes.font.xsm
                                        color: card.focused ? Colorscheme.on_surface : Colorscheme.on_surface_variant
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.focusGroup = groupCol.index
                                            root.focusItem = card.index
                                            root.activateFocused()
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
}
