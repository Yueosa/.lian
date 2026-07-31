// SwitcherPage — 按工作区分组的窗口切换器
//
// 相对旧 qs：
// 1. 性能：ListView reuseItems；仅视口附近 Screencopy；焦点卡 live
// 2. 缩略图：可见卡静帧 + 重试；失败用 app icon（小 sourceSize）
// 3. 定位：横/纵 positionViewAtIndex；开页定位活动窗口
// 4. 跳转：目标写入 Island；壳层 Enter / 单击 → activateSwitcherFocus
//
// 开销：视口内静帧 + 1 路 live；离页随 Hub Loader 销毁

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.data.state

FocusScope {
    id: root

    property int focusGroup: 0
    property int focusItem: 0

    // 只含有窗口的工作区；组内按 address 稳定排序
    readonly property var groups: {
        const out = []
        const wss = Hyprland.workspaces.values
        if (!wss)
            return out
        const sorted = wss.slice().sort((a, b) => {
            const ai = a && a.id !== undefined ? a.id : 0
            const bi = b && b.id !== undefined ? b.id : 0
            return ai - bi
        })
        for (let i = 0; i < sorted.length; ++i) {
            const ws = sorted[i]
            if (!ws || !ws.toplevels)
                continue
            const wins = ws.toplevels.values.slice().sort((a, b) => {
                const aa = (a && a.address) || ""
                const bb = (b && b.address) || ""
                return aa < bb ? -1 : (aa > bb ? 1 : 0)
            })
            if (wins.length === 0)
                continue
            out.push({ ws: ws, wins: wins })
        }
        return out
    }

    function clampFocus() {
        if (groups.length === 0) {
            focusGroup = 0
            focusItem = 0
            return
        }
        focusGroup = Math.max(0, Math.min(groups.length - 1, focusGroup))
        const rows = groups[focusGroup].wins.length
        focusItem = Math.max(0, Math.min(rows - 1, focusItem))
    }

    function locateActive() {
        const active = Hyprland.activeToplevel
        const focusedWs = Hyprland.focusedWorkspace
        const activeAddr = active ? (active.address || "") : ""
        const wsId = focusedWs ? focusedWs.id : -1
        let g = -1
        let it = 0

        if (activeAddr) {
            for (let i = 0; i < groups.length; ++i) {
                const wins = groups[i].wins
                for (let j = 0; j < wins.length; ++j) {
                    if (wins[j] && wins[j].address === activeAddr) {
                        g = i
                        it = j
                        break
                    }
                }
                if (g >= 0)
                    break
            }
        }
        if (g < 0) {
            for (let i = 0; i < groups.length; ++i) {
                if (groups[i].ws && groups[i].ws.id === wsId) {
                    g = i
                    break
                }
            }
            if (g < 0)
                g = 0
        }
        focusGroup = g
        focusItem = it
        clampFocus()
        Qt.callLater(ensureFocusVisible)
    }

    function ensureFocusVisible() {
        if (groups.length === 0)
            return
        hList.positionViewAtIndex(focusGroup, ListView.Contain)
        focusScrollNonce++
    }

    // 纵列 ListView 在 delegate 内，用 nonce 触发当前列滚入
    property int focusScrollNonce: 0

    function syncSwitcherTarget() {
        if (focusGroup < 0 || focusGroup >= groups.length) {
            Island.clearSwitcherTarget()
            return
        }
        const grp = groups[focusGroup]
        const win = (focusItem >= 0 && focusItem < grp.wins.length)
            ? grp.wins[focusItem]
            : null
        if (!win) {
            Island.clearSwitcherTarget()
            return
        }
        let addr = win.address || ""
        if (!addr && win.lastIpcObject && win.lastIpcObject.address)
            addr = String(win.lastIpcObject.address)
        Island.setSwitcherTarget(grp.ws ? grp.ws.id : null, addr, win)
    }

    function activateFocused() {
        syncSwitcherTarget()
        Island.activateSwitcherFocus()
    }

    function iconFor(win) {
        if (!win)
            return "image://icon/application-x-executable"
        const wl = win.wayland
        let id = ""
        if (wl && wl.appId)
            id = String(wl.appId)
        const ipc = win.lastIpcObject
        if (!id && ipc && ipc.class)
            id = String(ipc.class)
        const lower = id.toLowerCase()
        // 常见 class ≠ 主题图标名
        if (lower === "splayer")
            return "file:///usr/share/icons/hicolor/512x512/apps/SPlayer.png"
        if (lower === "cursor")
            return "image://icon/co.anysphere.cursor"
        if (id.length > 0)
            return "image://icon/" + id
        return "image://icon/application-x-executable"
    }

    function titleFor(win) {
        if (!win)
            return ""
        return win.title || win.address || ""
    }

    function moveGroup(delta) {
        focusGroup = Math.max(0, Math.min(groups.length - 1, focusGroup + delta))
        clampFocus()
        ensureFocusVisible()
    }

    function moveItem(delta) {
        const rows = (groups[focusGroup] && groups[focusGroup].wins.length) || 0
        if (rows <= 0)
            return
        focusItem = Math.max(0, Math.min(rows - 1, focusItem + delta))
        ensureFocusVisible()
    }

    onFocusGroupChanged: syncSwitcherTarget()
    onFocusItemChanged: syncSwitcherTarget()
    onGroupsChanged: {
        clampFocus()
        Qt.callLater(ensureFocusVisible)
    }

    Component.onCompleted: {
        locateActive()
        syncSwitcherTarget()
        forceActiveFocus()
    }

    // 仅 Keys（Hub Loader 已交焦点）；Enter 由 IslandShell 统一处理
    Keys.onLeftPressed: (e) => { moveGroup(-1); e.accepted = true }
    Keys.onRightPressed: (e) => { moveGroup(1); e.accepted = true }
    Keys.onUpPressed: (e) => { moveItem(-1); e.accepted = true }
    Keys.onDownPressed: (e) => { moveItem(1); e.accepted = true }

    Text {
        anchors.centerIn: parent
        visible: groups.length === 0
        text: "没有可切换的窗口"
        color: Color.textMuted
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.xl
    }

    ListView {
        id: hList
        anchors.fill: parent
        anchors.margins: 4
        visible: groups.length > 0
        orientation: ListView.Horizontal
        clip: true
        model: root.groups
        spacing: Size.spacing.lg
        boundsBehavior: Flickable.StopAtBounds
        // 降离屏预取：每卡 Screencopy 静帧很贵，关功能只少缓存邻卡
        cacheBuffer: 48
        reuseItems: true

        ScrollBar.horizontal: ScrollBar {
            policy: hList.contentWidth > hList.width
                ? ScrollBar.AsNeeded
                : ScrollBar.AlwaysOff
            height: 6
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                const dx = event.angleDelta.x !== 0
                    ? event.angleDelta.x
                    : event.angleDelta.y
                const step = dx / 120 * 80
                const maxX = Math.max(0, hList.contentWidth - hList.width)
                hList.contentX = Math.max(0, Math.min(maxX, hList.contentX - step))
                event.accepted = true
            }
        }

        delegate: ColumnLayout {
            id: groupCol
            required property int index
            required property var modelData

            height: hList.height
            width: 200
            spacing: Size.spacing.sm

            readonly property int groupIndex: index
            readonly property bool groupFocused: groupIndex === root.focusGroup

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "工作区 " + (groupCol.modelData.ws && groupCol.modelData.ws.id !== undefined
                    ? groupCol.modelData.ws.id
                    : "?")
                color: groupCol.groupFocused
                    ? Color.textOnBackground
                    : Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.sm
                font.bold: groupCol.groupFocused
            }

            ListView {
                id: vList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: groupCol.modelData.wins
                spacing: Size.spacing.sm
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 32
                reuseItems: true

                Connections {
                    target: root
                    function onFocusScrollNonceChanged() {
                        if (groupCol.groupFocused)
                            vList.positionViewAtIndex(root.focusItem, ListView.Contain)
                    }
                }

                delegate: Item {
                    id: card
                    required property int index
                    required property var modelData

                    width: vList.width
                    height: 124

                    readonly property bool focused: groupCol.groupFocused
                        && index === root.focusItem
                    readonly property var win: modelData
                    readonly property var wayland: win ? win.wayland : null
                    // 仅视口附近建 Screencopy，滑出即拆 dmabuf（图标兜底仍在）
                    readonly property bool nearView: {
                        const cy = vList.contentY
                        const vh = vList.height
                        const y = card.y
                        return (y + card.height) > (cy - 24) && y < (cy + vh + 24)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Size.rounding.md
                        color: card.focused
                            ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.18)
                            : Color.surfaceHigh
                        border.width: card.focused ? 2 : 1
                        border.color: card.focused
                            ? Color.primary
                            : Color.outlineVariant
                    }

                    Item {
                        id: thumbBox
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.bottomMargin: 26
                        clip: true

                        Loader {
                            id: thumbLoader
                            anchors.fill: parent
                            active: !!card.wayland && (card.nearView || card.focused)
                            sourceComponent: Component {
                                ScreencopyView {
                                    id: thumb
                                    anchors.fill: parent
                                    captureSource: card.wayland
                                    live: card.focused
                                    paintCursor: false
                                    visible: hasContent
                                    smooth: true

                                    // 等 recording context 就绪再抓帧，避免 spam WARN
                                    Timer {
                                        id: stillDelay
                                        interval: 80
                                        repeat: false
                                        onTriggered: {
                                            if (thumb.captureSource && !thumb.live
                                                    && !thumb.hasContent)
                                                thumb.captureFrame()
                                        }
                                    }
                                    Timer {
                                        id: retry
                                        interval: 220
                                        repeat: false
                                        onTriggered: {
                                            if (thumb.captureSource && !thumb.live
                                                    && !thumb.hasContent)
                                                thumb.captureFrame()
                                        }
                                    }

                                    function scheduleStill() {
                                        if (!captureSource || live || hasContent)
                                            return
                                        stillDelay.restart()
                                        retry.restart()
                                    }

                                    onCaptureSourceChanged: scheduleStill()
                                    onLiveChanged: {
                                        if (!live)
                                            scheduleStill()
                                    }
                                    Component.onCompleted: scheduleStill()
                                }
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            source: root.iconFor(card.win)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            sourceSize: Qt.size(72, 72)
                            visible: (!thumbLoader.item || !thumbLoader.item.hasContent)
                                && status !== Image.Error
                            onStatusChanged: {
                                if (status === Image.Error
                                        && source !== "image://icon/application-x-executable")
                                    source = "image://icon/application-x-executable"
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        text: root.titleFor(card.win)
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        color: card.focused
                            ? Color.textOnBackground
                            : Color.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.focusGroup = groupCol.groupIndex
                            root.focusItem = card.index
                            root.activateFocused()
                        }
                    }
                }
            }
        }
    }
}
