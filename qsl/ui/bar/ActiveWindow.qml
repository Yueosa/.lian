// ActiveWindow — 活动窗口名药丸
// 布局对齐旧 quickshell：RowLayout 自然测宽，标题只设 maximumWidth+elide
// 外层 displayWidth：变长立刻撑开，变短再收拢；收拢时 clip 裁切，不把 Text.width 掐死
//
// 性能：无 MultiEffect；无 TextMetrics；无图片

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.data.state

Item {
    id: root

    readonly property int pillHeight: 36
    readonly property int hPad: 12
    readonly property int titleMax: 250

    implicitHeight: pillHeight
    implicitWidth: displayWidth
    width: displayWidth
    height: pillHeight
    clip: true

    // 内容真实宽度（与旧版 layout.width + 24 同构）
    readonly property real contentWidth: layout.implicitWidth + hPad * 2

    property real displayWidth: contentWidth

    onContentWidthChanged: {
        if (contentWidth >= displayWidth - 0.5) {
            widthAnim.stop()
            displayWidth = contentWidth
        } else {
            widthAnim.stop()
            widthAnim.from = displayWidth
            widthAnim.to = contentWidth
            widthAnim.start()
        }
    }

    NumberAnimation {
        id: widthAnim
        target: root
        property: "displayWidth"
        duration: Size.anim.slow
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: displayWidth = contentWidth

    function workspaceIdOf(obj) {
        if (!obj)
            return -1
        if (obj.id !== undefined && obj.id !== null)
            return Number(obj.id)
        if (obj.lastIpcObject && obj.lastIpcObject.id !== undefined && obj.lastIpcObject.id !== null)
            return Number(obj.lastIpcObject.id)
        return -1
    }

    function activeWorkspaceId() {
        if (!activeWindow)
            return -1
        const ws = activeWindow.workspace
        if (ws) {
            const id = workspaceIdOf(ws)
            if (id >= 0)
                return id
        }
        const ipcWs = activeWindow.lastIpcObject && activeWindow.lastIpcObject.workspace
        if (ipcWs) {
            if (ipcWs.id !== undefined && ipcWs.id !== null)
                return Number(ipcWs.id)
            if (ipcWs.name !== undefined && ipcWs.name !== null) {
                const m = String(ipcWs.name).match(/\d+/)
                if (m && m.length > 0)
                    return Number(m[0])
            }
        }
        return -1
    }

    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int focusedWorkspaceId: workspaceIdOf(focusedWorkspace)
    readonly property int activeWsId: activeWorkspaceId()
    readonly property bool activeOnFocusedWorkspace: {
        if (focusedWorkspaceId < 0)
            return true
        if (activeWsId < 0)
            return true
        return activeWsId === focusedWorkspaceId
    }
    readonly property bool focusedWorkspaceEmpty: {
        const ws = focusedWorkspace
        if (!ws)
            return true
        if (!ws.toplevels)
            return false
        return ws.toplevels.count <= 0
    }

    readonly property var activeWindow: Hyprland.activeToplevel
    readonly property string activeTitle: {
        if (!activeWindow)
            return "Desktop"
        if (!activeOnFocusedWorkspace)
            return "Desktop"
        if (focusedWorkspaceEmpty)
            return "Desktop"
        return activeWindow.title || "Desktop"
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.background
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.hPad
        spacing: Size.spacing.md

        Text {
            text: ""
            color: Color.primary
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.md
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.activeTitle
            color: Color.primary
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.md
            Layout.maximumWidth: root.titleMax
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
