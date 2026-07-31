// IpcPage — 已注册 IPC 一览（与 shell.qml IpcHandler 对齐）
// 静态目录；非运行时反射。调用：qs ipc call <target> <method> [args…]
// 性能：Flickable + 静态 model；随 Loader 销毁

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    readonly property var catalog: [
        {
            target: "lock",
            summary: "会话锁屏（ext-session-lock / qsl SessionLock）。",
            methods: [
                { sig: "lock()", desc: "锁定会话；已锁定时返回 ALREADY_LOCKED。" },
                { sig: "status()", desc: "返回 LOCKED 或 UNLOCKED。" }
            ]
        },
        {
            target: "island",
            summary: "灵动岛：Hub、媒体控制与层级切换。",
            methods: [
                { sig: "hub()", desc: "打开或关闭 Hub。" },
                { sig: "switcher()", desc: "打开 Hub 并切换至窗口切换页。" },
                { sig: "wallpaper()", desc: "打开 Hub 并切换至壁纸页。" },
                { sig: "media()", desc: "打开 Hub 并切换至媒体页。" },
                { sig: "weather()", desc: "打开 Hub 并切换至天气页。" },
                { sig: "close()", desc: "关闭 Hub；返回 CLOSED。" },
                { sig: "togglelayer()", desc: "切换一级岛 layer（Top / Overlay）。" },
                { sig: "mediatoggle()", desc: "切换当前媒体播放/暂停。" },
                { sig: "mediaprevious()", desc: "上一曲。" },
                { sig: "medianext()", desc: "下一曲。" }
            ]
        },
        {
            target: "sidebar",
            summary: "左侧栏（time / sys / keys / todo）。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭左侧栏。" },
                { sig: "open(view)", desc: "打开并切换至指定页。常用：time、sys、keys、todo；另有别名如 system→sys、hotkeys→keys。" },
                { sig: "next() / prev()", desc: "在已打开时循环切换标签页。" },
                { sig: "close()", desc: "关闭左侧栏。" }
            ]
        },
        {
            target: "rightbar",
            summary: "右侧栏（network / bluetooth / audio / updates）。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭右侧栏。" },
                { sig: "open(view)", desc: "打开并切换至指定页：network、bluetooth、audio、updates。" },
                { sig: "next() / prev()", desc: "在已打开时循环切换标签页。" },
                { sig: "close()", desc: "关闭右侧栏。" }
            ]
        },
        {
            target: "notif",
            summary: "通知中心与免打扰。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭通知中心。" },
                { sig: "open()", desc: "打开通知中心。" },
                { sig: "close()", desc: "关闭通知中心。" },
                { sig: "dnd()", desc: "切换免打扰；返回 DND_ON 或 DND_OFF。" }
            ]
        },
        {
            target: "settings",
            summary: "设置面板（架构 / 说明 / IPC / 维护 / 文件）。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭设置面板。" },
                { sig: "open(view)", desc: "打开并切换页。view：arch、guide、ipc、maintain、files；缺省为 arch。hotkeys / calendar 等别名映射至 files。" },
                { sig: "close()", desc: "关闭设置面板。" }
            ]
        },
        {
            target: "free-window-app",
            summary: "应用启动器浮动窗。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭。" },
                { sig: "open()", desc: "打开。" },
                { sig: "close()", desc: "关闭。" }
            ]
        },
        {
            target: "free-window-clipboard",
            summary: "剪贴板历史浮动窗。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭。" },
                { sig: "open()", desc: "打开。" },
                { sig: "close()", desc: "关闭。" }
            ]
        },
        {
            target: "websearch",
            summary: "Web 搜索条。",
            methods: [
                { sig: "toggle()", desc: "打开或关闭。" },
                { sig: "open()", desc: "打开。" },
                { sig: "close()", desc: "关闭。" }
            ]
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "IPC"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Text {
                Layout.fillWidth: true
                text: "下列条目与 shell 中注册的 IpcHandler 一致。调用示例：qs ipc call island hub"
                wrapMode: Text.WordWrap
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: col
                width: flick.width
                spacing: Size.spacing.md

                Repeater {
                    model: root.catalog
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: body.implicitHeight + 24
                        radius: Size.rounding.md
                        color: Color.surfaceHigh
                        border.width: Style.border.width
                        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                        ColumnLayout {
                            id: body
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: Size.spacing.sm

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Size.spacing.sm
                                Text {
                                    text: modelData.target
                                    font.bold: true
                                    font.pixelSize: Size.fontSize.md
                                    font.family: Size.fontMono
                                    color: Color.primary
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Size.fontSize.sm
                                    color: Color.textMuted
                                }
                            }

                            Repeater {
                                model: modelData.methods
                                delegate: ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sig
                                        font.family: Size.fontMono
                                        font.pixelSize: Size.fontSize.xsm
                                        color: Color.text
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.desc
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Size.fontSize.sm
                                        color: Color.textMuted
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
