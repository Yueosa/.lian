// NotifToastContent — 一级岛通知堆叠（对齐旧 DI）
// ≤3 条；每条 5s Timer + 底栏进度条；点击由 IslandShell 处理
// 开销：≤3 Image(async) + ≤3 Timer

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: toastRoot

    readonly property int rowH: 60
    readonly property int rowGap: Math.round(10 * Size.islandScale)

    Column {
        anchors.fill: parent
        spacing: toastRoot.rowGap

        Repeater {
            model: Island.notifToasts

            delegate: Item {
                id: row
                width: toastRoot.width
                height: toastRoot.rowH

                readonly property int toastKey: model.toastId
                readonly property string title: String(model.title || "")
                readonly property string body: String(model.body || "")
                readonly property string imagePath: String(model.imagePath || "")
                readonly property string desktopEntry: String(model.desktopEntry || "")
                readonly property string appName: String(model.appName || "")

                readonly property bool isIslandEvent:
                    desktopEntry.indexOf("quickshell-island-event") === 0
                    || appName.indexOf("IslandEventCenter") === 0

                // IslandEvent：desktopEntry = quickshell-island-event.<severity>.<category>
                readonly property color accent: {
                    if (!isIslandEvent)
                        return Color.primary
                    const parts = desktopEntry.split(".")
                    const sev = parts.length >= 2 ? parts[1] : ""
                    const cat = parts.length >= 3 ? parts[2] : ""
                    if (sev === "critical")
                        return Color.error
                    if (sev === "high")
                        return Color.tertiary
                    if (cat === "connection" || cat === "power")
                        return Color.secondary
                    return Color.primary
                }

                readonly property color titleColor: isIslandEvent ? accent : Color.backgroundText
                readonly property color bodyColor: isIslandEvent
                    ? Qt.rgba(accent.r, accent.g, accent.b, 0.88)
                    : Color.textMuted

                // icon:xxx / image://icon/xxx / 无路径裸名 → 主题图标
                // 绝对路径 / file:// / 其它 image:// → 文件或句柄
                readonly property bool isThemeIcon: {
                    const p = imagePath
                    if (p.length === 0)
                        return false
                    if (p.indexOf("icon:") === 0 || p.indexOf("image://icon/") === 0)
                        return true
                    if (p.indexOf("image://") === 0 || p.indexOf("file://") === 0)
                        return false
                    if (p.indexOf("/") >= 0)
                        return false
                    // co.anysphere.cursor、dialog-information 等
                    return true
                }
                readonly property string iconSource: {
                    const p = imagePath
                    if (p.length === 0)
                        return ""
                    if (p.indexOf("icon:") === 0)
                        return "image://icon/" + p.substring(5)
                    if (p.indexOf("image://icon/") === 0 || p.indexOf("image://") === 0
                        || p.indexOf("file://") === 0)
                        return p
                    if (p.indexOf("/") === 0)
                        return "file://" + p
                    if (isThemeIcon)
                        return "image://icon/" + p
                    return p
                }

                Timer {
                    interval: Island.notifToastMs
                    running: true
                    repeat: false
                    onTriggered: Island.clearNotifAt(row.toastKey)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.bottomMargin: 4
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: Size.rounding.md
                        color: Color.background
                        clip: true

                        Image {
                            id: iconImage
                            anchors.fill: parent
                            anchors.margins: row.isThemeIcon ? 6 : 0
                            source: row.iconSource
                            fillMode: row.isThemeIcon
                                ? Image.PreserveAspectFit
                                : Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(80, 80)
                            visible: row.iconSource.length > 0
                                && status !== Image.Error
                                && status !== Image.Null
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf0f3"
                            visible: !iconImage.visible
                            font.family: Size.fontMono
                            font.pixelSize: Size.iconSize.lg
                            color: row.titleColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Text {
                            text: row.title
                            textFormat: Text.PlainText
                            color: row.titleColor
                            font.family: Size.fontSans
                            font.bold: true
                            font.pixelSize: Size.fontSize.titleSmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: row.body
                            textFormat: Text.PlainText
                            color: row.bodyColor
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.bodySmall
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 2
                    radius: 1
                    color: row.accent
                    width: row.width - 20

                    // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                    NumberAnimation on width {
                        from: row.width - 20
                        to: 0
                        duration: Island.notifToastMs
                        running: true
                    }
                }
            }
        }
    }
}
