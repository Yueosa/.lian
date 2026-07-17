// ActiveWindow — 活动窗口名药丸
// displayWidth 弹性动画；文字宽度跟当前 displayWidth，避免标题抢跑撑破容器
//
// 性能：TextMetrics 测宽；无 MultEffect；无图片

import QtQuick
import Quickshell.Hyprland
import qs.data.state

Item {
    id: root

    readonly property int pillHeight: 36
    readonly property int hPad: 12
    readonly property int iconSize: Size.fontSize.md
    readonly property int titleMax: 250
    readonly property int gap: Size.spacing.md

    implicitHeight: pillHeight
    implicitWidth: displayWidth
    width: displayWidth
    height: pillHeight
    clip: true

    property real displayWidth: targetWidth
    readonly property real targetWidth: {
        const titleW = Math.min(titleMetrics.width, titleMax)
        return hPad + iconSize + gap + titleW + hPad
    }

    Behavior on displayWidth {
        NumberAnimation {
            duration: Size.anim.slow
            easing.type: Easing.OutCubic
        }
    }

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

    TextMetrics {
        id: titleMetrics
        font.family: Size.fontMono
        font.pixelSize: Size.fontSize.md
        text: root.activeTitle
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.background
    }

    Text {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: root.hPad
        anchors.verticalCenter: parent.verticalCenter
        text: ""
        color: Color.primary
        font.family: Size.fontMono
        font.pixelSize: root.iconSize
    }

    Text {
        id: windowTitle
        anchors.left: icon.right
        anchors.leftMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter
        // 可见宽度跟当前药丸，不跟完整标题 preferredWidth
        width: Math.max(0, root.displayWidth - root.hPad - root.iconSize - root.gap - root.hPad)
        text: root.activeTitle
        font.family: Size.fontMono
        font.pixelSize: Size.fontSize.md
        color: Color.primary
        elide: Text.ElideRight
        clip: true
    }
}
