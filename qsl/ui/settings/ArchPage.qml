// ArchPage — 分层架构图（仅图）
// UI → QML 数据 → 后端；点选高亮关联边
// 性能：静态节点/边；无 Timer / 无反射；随 Loader 销毁

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    readonly property var nodes: [
        { id: "bar", layer: "ui", label: "Bar", x: 0.14, y: 0.20 },
        { id: "island", layer: "ui", label: "Island", x: 0.38, y: 0.14 },
        { id: "leftbar", layer: "ui", label: "Left", x: 0.62, y: 0.20 },
        { id: "rightbar", layer: "ui", label: "Right", x: 0.86, y: 0.20 },
        { id: "notif", layer: "ui", label: "通知中心", x: 0.14, y: 0.38 },
        { id: "app", layer: "ui", label: "App", x: 0.38, y: 0.38 },
        { id: "websearch", layer: "ui", label: "WebSearch", x: 0.62, y: 0.38 },
        { id: "clipboard", layer: "ui", label: "剪贴板", x: 0.86, y: 0.38 },
        { id: "service", layer: "data", label: "service", x: 0.22, y: 0.64 },
        { id: "state", layer: "data", label: "state", x: 0.50, y: 0.64 },
        { id: "freewindow", layer: "data", label: "freewindow", x: 0.78, y: 0.64 },
        { id: "be_rust", layer: "backend", label: "Rust", x: 0.22, y: 0.88 },
        { id: "be_cava", layer: "backend", label: "cava", x: 0.50, y: 0.88 },
        { id: "be_theme", layer: "backend", label: "主题管线", x: 0.78, y: 0.88 }
    ]

    readonly property var edges: [
        { from: "be_rust", to: "service" },
        { from: "be_cava", to: "service" },
        { from: "be_theme", to: "state" },
        { from: "service", to: "state" },
        { from: "service", to: "freewindow" },
        { from: "service", to: "bar" },
        { from: "service", to: "island" },
        { from: "service", to: "leftbar" },
        { from: "service", to: "rightbar" },
        { from: "service", to: "notif" },
        { from: "state", to: "island" },
        { from: "freewindow", to: "app" },
        { from: "freewindow", to: "clipboard" }
    ]

    property string selectedId: "island"
    property string hoverId: ""

    function nodeById(id) {
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].id === id)
                return nodes[i]
        }
        return null
    }

    function layerFill(layer, selected) {
        if (selected)
            return Color.withAlpha(Color.primary, 0.20)
        if (layer === "ui")
            return Color.surfaceHigh
        if (layer === "data")
            return Color.surface
        return Color.withAlpha(Color.surfaceHighest, 0.92)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "架构"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Text {
                Layout.fillWidth: true
                text: "自上而下为界面层、数据层与后端；自下而上为数据依赖方向。点选节点可高亮相关连线。模块说明见「说明」页。"
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: graph
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                model: [
                    { label: "界面", y: 0.08 },
                    { label: "数据", y: 0.54 },
                    { label: "后端", y: 0.80 }
                ]
                delegate: Text {
                    required property var modelData
                    x: 6
                    y: modelData.y * graph.height
                    text: modelData.label
                    font.pixelSize: Size.fontSize.xsm
                    color: Color.textMuted
                    opacity: 0.65
                }
            }

            Canvas {
                id: edgeCanvas
                anchors.fill: parent
                z: 0
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const sel = root.selectedId
                    for (let i = 0; i < root.edges.length; i++) {
                        const e = root.edges[i]
                        const a = root.nodeById(e.from)
                        const b = root.nodeById(e.to)
                        if (!a || !b)
                            continue
                        const hot = (e.from === sel || e.to === sel)
                        ctx.strokeStyle = hot
                            ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.80)
                            : Qt.rgba(Color.outline.r, Color.outline.g, Color.outline.b, 0.32)
                        ctx.lineWidth = hot ? 2.2 : 1.2
                        const x1 = a.x * width
                        const y1 = a.y * height
                        const x2 = b.x * width
                        const y2 = b.y * height
                        ctx.beginPath()
                        ctx.moveTo(x1, y1)
                        ctx.bezierCurveTo(x1, (y1 + y2) / 2, x2, (y1 + y2) / 2, x2, y2)
                        ctx.stroke()
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            Connections {
                target: root
                function onSelectedIdChanged() { edgeCanvas.requestPaint() }
            }

            Repeater {
                model: root.nodes
                delegate: Item {
                    id: nodeItem
                    required property var modelData
                    readonly property bool selected: root.selectedId === modelData.id
                    readonly property bool hovered: root.hoverId === modelData.id

                    z: 1
                    width: Math.max(96, labelText.implicitWidth + 28)
                    height: 44
                    x: modelData.x * graph.width - width / 2
                    y: modelData.y * graph.height - height / 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Size.rounding.md
                        color: root.layerFill(nodeItem.modelData.layer, nodeItem.selected)
                        border.width: nodeItem.selected ? 2 : Style.border.width
                        border.color: (nodeItem.selected || nodeItem.hovered)
                            ? Color.primary
                            : Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                        Text {
                            id: labelText
                            anchors.centerIn: parent
                            text: nodeItem.modelData.label
                            font.bold: true
                            font.pixelSize: Size.fontSize.sm
                            color: nodeItem.selected ? Color.primary : Color.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverId = nodeItem.modelData.id
                        onExited: {
                            if (root.hoverId === nodeItem.modelData.id)
                                root.hoverId = ""
                        }
                        onClicked: root.selectedId = nodeItem.modelData.id
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: {
                const n = root.nodeById(root.selectedId)
                return n ? ("当前选中：" + n.label) : ""
            }
            font.pixelSize: Size.fontSize.xsm
            color: Color.textMuted
        }
    }
}
