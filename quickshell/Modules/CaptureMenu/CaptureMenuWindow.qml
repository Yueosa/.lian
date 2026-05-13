import QtQuick
import QtQuick.Layouts
import Quickshell
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

    WlrLayershell.namespace: "qs-capture-menu-overlay"
    WlrLayershell.layer: WidgetState.shouldOverlayTransient(root.visible) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property string mode: "screenshot"
    property string scope: "region"
    readonly property string captureScriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/capture.sh"

    readonly property var modeItems: [
        { key: "screenshot", label: "Shot" },
        { key: "gif", label: "GIF" },
        { key: "video", label: "Video" }
    ]
    readonly property var scopeItems: [
        { key: "region", label: "Region" },
        { key: "full", label: "Full" }
    ]

    function showWindow() {
        visible = true
    }

    function hideWindow() {
        visible = false
    }

    function toggleWindow() {
        visible = !visible
    }

    function setMode(nextMode) {
        if (nextMode === "screenshot" || nextMode === "gif" || nextMode === "video")
            mode = nextMode
    }

    function setScope(nextScope) {
        if (nextScope === "region" || nextScope === "full")
            scope = nextScope
    }

    function cycleMode(step) {
        let index = 0
        for (let i = 0; i < modeItems.length; ++i) {
            if (modeItems[i].key === mode) {
                index = i
                break
            }
        }
        const next = (index + step + modeItems.length) % modeItems.length
        mode = modeItems[next].key
    }

    function cycleScope(step) {
        let index = 0
        for (let i = 0; i < scopeItems.length; ++i) {
            if (scopeItems[i].key === scope) {
                index = i
                break
            }
        }
        const next = (index + step + scopeItems.length) % scopeItems.length
        scope = scopeItems[next].key
    }

    function currentRegionGeometry() {
        return Math.round(selectionFrame.x) + "," + Math.round(selectionFrame.y)
            + " " + Math.round(selectionFrame.width) + "x" + Math.round(selectionFrame.height)
    }

    function triggerPrimary() {
        const geometry = scope === "region" ? currentRegionGeometry() : ""

        if (mode === "screenshot") {
            const args = ["bash", captureScriptPath, "shot", scope]
            if (geometry.length > 0)
                args.push(geometry)

            Quickshell.execDetached(args)
            hideWindow()
            return "SHOT_TRIGGERED"
        }

        const args = ["bash", captureScriptPath, "record-toggle", mode, scope]
        if (geometry.length > 0)
            args.push(geometry)

        Quickshell.execDetached(args)
        hideWindow()
        return "RECORD_TRIGGERED"
    }

    onVisibleChanged: {
        if (visible && scope === "region")
            selectionFrame.resetGeometry()
    }

    onScopeChanged: {
        if (visible && scope === "region")
            selectionFrame.resetGeometry()
    }

    function triggerForceStop() {
        Quickshell.execDetached(["bash", captureScriptPath, "force-stop"])
        hideWindow()
        return "STOP_TRIGGERED"
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colorscheme.scrim.r, Colorscheme.scrim.g, Colorscheme.scrim.b, 0.5)
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        enabled: root.visible
        focus: root.visible

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.hideWindow()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Tab) {
                root.cycleMode((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_F) {
                root.setScope("full")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_R) {
                root.setScope("region")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_C) {
                root.setMode("screenshot")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_G) {
                root.setMode("gif")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_V) {
                root.setMode("video")
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                root.triggerPrimary()
                event.accepted = true
                return
            }
        }

        MouseArea {
            id: stageMouseArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: root.scope === "region"

            function containsPoint(item, px, py) {
                const local = item.mapFromItem(keyScope, px, py)
                return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height
            }

            onPressed: mouse => {
                if (root.scope !== "region") {
                    mouse.accepted = false
                    return
                }

                if (containsPoint(selectionFrame, mouse.x, mouse.y)
                    || containsPoint(floatingToolbar, mouse.x, mouse.y)) {
                    mouse.accepted = false
                    return
                }

                selectionFrame.moveCenterTo(mouse.x, mouse.y)
                mouse.accepted = true
            }

            onClicked: mouse => {
                if (root.scope === "region") {
                    if (containsPoint(selectionFrame, mouse.x, mouse.y)
                        || containsPoint(floatingToolbar, mouse.x, mouse.y)) {
                        mouse.accepted = false
                        return
                    }
                    selectionFrame.moveCenterTo(mouse.x, mouse.y)
                    mouse.accepted = true
                    return
                }
                root.hideWindow()
            }
        }

        Rectangle {
            id: selectionFrame
            visible: root.scope === "region"
            width: 0
            height: 0
            x: 0
            y: 0
            color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.08)
            border.width: 2
            border.color: Colorscheme.primary
            radius: Sizes.rounding.large
            z: 10

            property real minWidth: 260
            property real minHeight: 180
            property string resizeHandle: ""
            property real resizeStartMouseX: 0
            property real resizeStartMouseY: 0
            property real resizeStartX: 0
            property real resizeStartY: 0
            property real resizeStartWidth: 0
            property real resizeStartHeight: 0
            property bool dragging: false
            property real dragStartX: 0
            property real dragStartY: 0
            property real dragStartMouseX: 0
            property real dragStartMouseY: 0

            Component.onCompleted: resetGeometry()

            function resetGeometry() {
                if (root.width <= 0 || root.height <= 0)
                    return

                width = Math.round(root.width * 0.44)
                height = Math.round(root.height * 0.42)
                x = Math.round((root.width - width) / 2)
                y = Math.round((root.height - height) / 2)
                clampInBounds()
            }

            function clampInBounds() {
                if (x < 0)
                    x = 0
                if (y < 0)
                    y = 0
                if (width < minWidth)
                    width = minWidth
                if (height < minHeight)
                    height = minHeight
                if (x + width > root.width)
                    x = Math.max(0, root.width - width)
                if (y + height > root.height)
                    y = Math.max(0, root.height - height)
            }

            function moveCenterTo(pointX, pointY) {
                x = Math.round(pointX - width / 2)
                y = Math.round(pointY - height / 2)
                clampInBounds()
            }

            function startResize(handle, globalX, globalY) {
                dragging = false
                resizeHandle = handle
                resizeStartMouseX = globalX
                resizeStartMouseY = globalY
                resizeStartX = x
                resizeStartY = y
                resizeStartWidth = width
                resizeStartHeight = height
            }

            function updateResize(globalX, globalY) {
                if (resizeHandle.length === 0)
                    return

                const dx = globalX - resizeStartMouseX
                const dy = globalY - resizeStartMouseY
                const right = resizeStartX + resizeStartWidth
                const bottom = resizeStartY + resizeStartHeight

                const hasLeft = resizeHandle.indexOf("w") !== -1
                const hasRight = resizeHandle.indexOf("e") !== -1
                const hasTop = resizeHandle.indexOf("n") !== -1
                const hasBottom = resizeHandle.indexOf("s") !== -1

                let nextX = resizeStartX
                let nextY = resizeStartY
                let nextWidth = resizeStartWidth
                let nextHeight = resizeStartHeight

                if (hasLeft) {
                    nextX = resizeStartX + dx
                    nextWidth = resizeStartWidth - dx
                }
                if (hasRight)
                    nextWidth = resizeStartWidth + dx

                if (hasTop) {
                    nextY = resizeStartY + dy
                    nextHeight = resizeStartHeight - dy
                }
                if (hasBottom)
                    nextHeight = resizeStartHeight + dy

                if (nextWidth < minWidth) {
                    nextWidth = minWidth
                    if (hasLeft)
                        nextX = right - nextWidth
                }
                if (nextHeight < minHeight) {
                    nextHeight = minHeight
                    if (hasTop)
                        nextY = bottom - nextHeight
                }

                if (hasLeft && nextX < 0) {
                    nextX = 0
                    nextWidth = right - nextX
                }
                if (hasTop && nextY < 0) {
                    nextY = 0
                    nextHeight = bottom - nextY
                }

                if (hasRight && nextX + nextWidth > root.width)
                    nextWidth = root.width - nextX
                if (hasBottom && nextY + nextHeight > root.height)
                    nextHeight = root.height - nextY

                if (nextWidth < minWidth) {
                    nextWidth = minWidth
                    if (hasLeft)
                        nextX = right - nextWidth
                }
                if (nextHeight < minHeight) {
                    nextHeight = minHeight
                    if (hasTop)
                        nextY = bottom - nextHeight
                }

                x = Math.max(0, Math.min(root.width - nextWidth, nextX))
                y = Math.max(0, Math.min(root.height - nextHeight, nextY))
                width = Math.max(minWidth, Math.min(root.width, nextWidth))
                height = Math.max(minHeight, Math.min(root.height, nextHeight))
            }

            function stopResize() {
                resizeHandle = ""
            }

            function startDrag(globalX, globalY) {
                resizeHandle = ""
                dragging = true
                dragStartX = x
                dragStartY = y
                dragStartMouseX = globalX
                dragStartMouseY = globalY
            }

            function updateDrag(globalX, globalY) {
                if (!dragging)
                    return

                const dx = globalX - dragStartMouseX
                const dy = globalY - dragStartMouseY
                x = dragStartX + dx
                y = dragStartY + dy
                clampInBounds()
            }

            function stopDrag() {
                dragging = false
            }

            onXChanged: clampInBounds()
            onYChanged: clampInBounds()
            onWidthChanged: clampInBounds()
            onHeightChanged: clampInBounds()

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                radius: Sizes.rounding.chip
                color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.85)
                border.width: 1
                border.color: Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.5)
                width: frameHint.implicitWidth + 16
                height: 26

                Text {
                    id: frameHint
                    anchors.centerIn: parent
                    text: "Region frame"
                    color: Colorscheme.on_surface
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: selectionFrame.resizeHandle.length === 0
                cursorShape: Qt.SizeAllCursor
                onPressed: mouse => {
                    const p = selectionFrame.mapToItem(keyScope, mouse.x, mouse.y)
                    selectionFrame.startDrag(p.x, p.y)
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const p = selectionFrame.mapToItem(keyScope, mouse.x, mouse.y)
                    selectionFrame.updateDrag(p.x, p.y)
                }
                onReleased: selectionFrame.stopDrag()
                onCanceled: selectionFrame.stopDrag()
            }

            Rectangle {
                id: handleNw
                z: 2
                width: 14
                height: 14
                radius: 7
                color: Colorscheme.primary
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: -Math.round(width / 2)
                anchors.topMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: mouse => {
                        const p = handleNw.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("nw", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleNw.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleNe
                z: 2
                width: 14
                height: 14
                radius: 7
                color: Colorscheme.primary
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -Math.round(width / 2)
                anchors.topMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: mouse => {
                        const p = handleNe.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("ne", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleNe.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleSw
                z: 2
                width: 14
                height: 14
                radius: 7
                color: Colorscheme.primary
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: -Math.round(width / 2)
                anchors.bottomMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: mouse => {
                        const p = handleSw.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("sw", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleSw.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleSe
                z: 2
                width: 14
                height: 14
                radius: 7
                color: Colorscheme.primary
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -Math.round(width / 2)
                anchors.bottomMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: mouse => {
                        const p = handleSe.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("se", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleSe.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleN
                z: 2
                width: 38
                height: 10
                radius: 5
                color: Colorscheme.primary
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    onPressed: mouse => {
                        const p = handleN.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("n", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleN.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleS
                z: 2
                width: 38
                height: 10
                radius: 5
                color: Colorscheme.primary
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -Math.round(height / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    onPressed: mouse => {
                        const p = handleS.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("s", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleS.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleW
                z: 2
                width: 10
                height: 38
                radius: 5
                color: Colorscheme.primary
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: -Math.round(width / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    onPressed: mouse => {
                        const p = handleW.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("w", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleW.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }

            Rectangle {
                id: handleE
                z: 2
                width: 10
                height: 38
                radius: 5
                color: Colorscheme.primary
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: -Math.round(width / 2)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeHorCursor
                    onPressed: mouse => {
                        const p = handleE.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.startResize("e", p.x, p.y)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed)
                            return
                        const p = handleE.mapToItem(keyScope, mouse.x, mouse.y)
                        selectionFrame.updateResize(p.x, p.y)
                    }
                    onReleased: selectionFrame.stopResize()
                    onCanceled: selectionFrame.stopResize()
                }
            }
        }

        Rectangle {
            id: floatingToolbar
            z: 11
            width: 456
            height: 108
            readonly property real dockMargin: 24
            readonly property bool frameCoversScreen: selectionFrame.visible
                && selectionFrame.x <= 2
                && selectionFrame.y <= 2
                && selectionFrame.x + selectionFrame.width >= root.width - 2
                && selectionFrame.y + selectionFrame.height >= root.height - 2
            radius: Sizes.rounding.xl
            color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.5)
            x: {
                const margin = 16
                if (!selectionFrame.visible || frameCoversScreen)
                    return Math.max(margin, root.width - width - dockMargin)

                const sideGap = 14
                const rightDock = selectionFrame.x + selectionFrame.width + sideGap
                if (rightDock + width <= root.width - margin)
                    return rightDock

                const screenRightDock = root.width - width - dockMargin
                if (screenRightDock >= margin)
                    return screenRightDock

                const leftDock = selectionFrame.x - width - sideGap
                if (leftDock >= margin)
                    return leftDock

                const centered = selectionFrame.x + selectionFrame.width / 2 - width / 2
                return Math.max(margin, Math.min(root.width - width - margin, centered))
            }
            y: {
                const margin = 16
                if (!selectionFrame.visible || frameCoversScreen)
                    return Math.max(margin, root.height - height - dockMargin)

                const verticalGap = 12
                const below = selectionFrame.y + selectionFrame.height + verticalGap
                if (below + height <= root.height - margin)
                    return below

                const screenBottomDock = root.height - height - dockMargin
                if (screenBottomDock >= margin)
                    return screenBottomDock

                const above = selectionFrame.y - height - verticalGap
                if (above >= margin)
                    return above

                return Math.max(margin, Math.min(root.height - height - margin, selectionFrame.y))
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse => mouse.accepted = true
                onClicked: mouse => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    spacing: 6

                    Repeater {
                        model: root.modeItems

                        delegate: Rectangle {
                            readonly property bool active: root.mode === modelData.key
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: Math.max(68, modeLabel.implicitWidth + 20)
                            radius: Sizes.rounding.chip
                            color: active
                                ? Colorscheme.primary
                                : Qt.rgba(Colorscheme.surface_container.r, Colorscheme.surface_container.g, Colorscheme.surface_container.b, 0.9)
                            border.width: 1
                            border.color: active
                                ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.95)
                                : Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.45)

                            Text {
                                id: modeLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: active ? Colorscheme.on_primary : Colorscheme.on_surface
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.sm
                                font.bold: active
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setMode(modelData.key)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: Math.max(84, actionLabel.implicitWidth + 20)
                        radius: Sizes.rounding.chip
                        color: Colorscheme.secondary

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: root.mode === "screenshot" ? "Capture" : "Record"
                            color: Colorscheme.on_secondary
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.triggerPrimary()
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: Math.max(72, stopLabel.implicitWidth + 20)
                        radius: Sizes.rounding.chip
                        color: Colorscheme.error_container

                        Text {
                            id: stopLabel
                            anchors.centerIn: parent
                            text: "Stop"
                            color: Colorscheme.on_error_container
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.triggerForceStop()
                        }
                    }
                }

                RowLayout {
                    spacing: 6

                    Repeater {
                        model: root.scopeItems

                        delegate: Rectangle {
                            readonly property bool active: root.scope === modelData.key
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: Math.max(72, scopeLabel.implicitWidth + 18)
                            radius: Sizes.rounding.chip
                            color: active
                                ? Colorscheme.tertiary
                                : Qt.rgba(Colorscheme.surface_container.r, Colorscheme.surface_container.g, Colorscheme.surface_container.b, 0.9)
                            border.width: 1
                            border.color: active
                                ? Qt.rgba(Colorscheme.tertiary.r, Colorscheme.tertiary.g, Colorscheme.tertiary.b, 0.95)
                                : Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.45)

                            Text {
                                id: scopeLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: active ? Colorscheme.on_tertiary : Colorscheme.on_surface
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.xs
                                font.bold: active
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setScope(modelData.key)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "ESC close"
                        color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.72)
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.xs
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Rectangle {
            z: 11
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24
            width: titleLabel.implicitWidth + 24
            height: 34
            radius: Sizes.rounding.chipPlus
            color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.9)
            border.width: 1
            border.color: Qt.rgba(Colorscheme.outline.r, Colorscheme.outline.g, Colorscheme.outline.b, 0.5)

            Text {
                id: titleLabel
                anchors.centerIn: parent
                text: "Capture menu"
                color: Colorscheme.on_surface
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.sm
                font.bold: true
            }
        }
    }
}
