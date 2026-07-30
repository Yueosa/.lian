// ArchPage — 设置首页：动态架构图（静态节点/边 + hover）
// 性能：节点固定 ≤15；关窗随 Loader 销毁；无 Timer / 无反射

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state

Item {
    id: root

    // 归一化坐标 0–1（相对图画区）
    readonly property var nodes: [
        { id: "bar", label: "Bar", x: 0.50, y: 0.10, icon: "toolbar",
          desc: "顶栏：工作区、托盘、SysMonitor、网络/蓝牙/音量芯片、设置入口。" },
        { id: "island", label: "Island", x: 0.50, y: 0.28, icon: "nest_eco_leaf",
          desc: "灵动岛：Overview / Media / Wallpaper / Weather / Switcher；单 Loader 关即毁。" },
        { id: "leftbar", label: "Leftbar", x: 0.18, y: 0.48, icon: "view_sidebar",
          desc: "左侧栏：计时、系统监视、键位、待办。detailActive 关页停扫。" },
        { id: "rightbar", label: "Rightbar", x: 0.82, y: 0.48, icon: "view_sidebar",
          desc: "右侧栏：网络、蓝牙、声音、更新。运行时快捷面板，不进设置主页。" },
        { id: "free", label: "FreeWindows", x: 0.18, y: 0.72, icon: "web_asset",
          desc: "App / 剪贴板 / WebSearch / 本设置窗。关窗 mask=0，重页随 Loader 销毁。" },
        { id: "svc", label: "Services", x: 0.50, y: 0.58, icon: "hub",
          desc: "QML 单例服务：Network、Bluetooth、Volume、Cava、Sysmon、Todo… 多为薄封装。" },
        { id: "be", label: "Backends", x: 0.82, y: 0.72, icon: "memory",
          desc: "外部进程：cava-relay、sysmond、weatherd。重活不进 QML 主线程。" },
        { id: "theme", label: "Theme", x: 0.50, y: 0.88, icon: "palette",
          desc: "壁纸 → lianwall → matugen → Color token；换肤时有 ColorAnimation 通知。" }
    ]

    readonly property var edges: [
        { from: "bar", to: "island" },
        { from: "bar", to: "svc" },
        { from: "island", to: "svc" },
        { from: "leftbar", to: "svc" },
        { from: "rightbar", to: "svc" },
        { from: "free", to: "svc" },
        { from: "svc", to: "be" },
        { from: "island", to: "theme" },
        { from: "theme", to: "svc" }
    ]

    property string hoverId: ""
    readonly property var hoverNode: {
        if (!hoverId)
            return null
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].id === hoverId)
                return nodes[i]
        }
        return null
    }

    function nodeById(id) {
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].id === id)
                return nodes[i]
        }
        return null
    }

    function deepLink(id) {
        switch (id) {
        case "rightbar":
            Quickshell.execDetached(["qs", "ipc", "call", "rightbar", "open", "network"])
            return
        case "leftbar":
            Quickshell.execDetached(["qs", "ipc", "call", "sidebar", "open", "sys"])
            return
        case "island":
            Quickshell.execDetached(["qs", "ipc", "call", "island", "hub"])
            return
        case "free":
            Quickshell.execDetached(["qs", "ipc", "call", "free-window-app", "toggle"])
            return
        default:
            break
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "qsl 架构"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Text {
                Layout.fillWidth: true
                text: "模块与数据流示意 · hover 看说明 · 点节点可深链到运行时面板"
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: graph
            Layout.fillWidth: true
            Layout.fillHeight: true

            // 边
            Canvas {
                id: edgeCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Qt.rgba(Color.outline.r, Color.outline.g, Color.outline.b, 0.45)
                    ctx.lineWidth = 1.5
                    for (let i = 0; i < root.edges.length; i++) {
                        const e = root.edges[i]
                        const a = root.nodeById(e.from)
                        const b = root.nodeById(e.to)
                        if (!a || !b)
                            continue
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

            Repeater {
                model: root.nodes
                delegate: Item {
                    id: node
                    required property var modelData
                    readonly property bool hot: root.hoverId === modelData.id

                    width: 108
                    height: 52
                    x: modelData.x * graph.width - width / 2
                    y: modelData.y * graph.height - height / 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Size.rounding.md
                        color: node.hot
                            ? Color.withAlpha(Color.primary, 0.18)
                            : Color.surfaceHigh
                        border.width: node.hot ? 2 : Style.border.width
                        border.color: node.hot
                            ? Color.primary
                            : Color.withAlpha(Color.outlineVariant, Style.border.opacity)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: node.modelData.icon
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.lg
                                color: node.hot ? Color.primary : Color.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: node.modelData.label
                                font.bold: true
                                font.pixelSize: Size.fontSize.sm
                                color: node.hot ? Color.primary : Color.text
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoverId = node.modelData.id
                        onExited: {
                            if (root.hoverId === node.modelData.id)
                                root.hoverId = ""
                        }
                        onClicked: root.deepLink(node.modelData.id)
                    }
                }
            }

            // hover 说明卡
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: Math.min(360, parent.width * 0.42)
                height: tipCol.implicitHeight + 24
                radius: Size.rounding.md
                visible: !!root.hoverNode
                color: Color.withAlpha(Color.surface, 0.95)
                border.width: 1
                border.color: Color.outlineVariant

                ColumnLayout {
                    id: tipCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 4
                    Text {
                        text: root.hoverNode ? root.hoverNode.label : ""
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.primary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hoverNode ? root.hoverNode.desc : ""
                        wrapMode: Text.WordWrap
                        font.pixelSize: Size.fontSize.sm
                        color: Color.textMuted
                    }
                }
            }
        }
    }
}
