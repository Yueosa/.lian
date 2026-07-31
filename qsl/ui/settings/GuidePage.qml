// GuidePage — 架构说明（模块、数据流、Island 抢占）
// 性能：静态文案；Flickable 滚动；随 Loader 销毁

import QtQuick
import QtQuick.Layouts
import qs.data.state

Item {
    id: root

    readonly property var sections: [
        {
            title: "分层结构",
            body: "qsl 自上而下分为界面层、数据层与后端。界面层负责交互与展示；数据层以 QML 单例提供状态与业务封装；后端为独立进程，承担采集、守护与主题生成等不宜进入 UI 主线程的工作。数据依赖方向为自下而上。"
        },
        {
            title: "界面层",
            items: [
                {
                    name: "Bar",
                    text: "顶栏常驻表面：工作区、焦点窗口、应用托盘、硬件性能指示，以及媒体与网络相关状态芯片。"
                },
                {
                    name: "Island",
                    text: "灵动岛。Hub 提供 Overview、Media、Wallpaper、Weather、Switcher；收起态由状态机在时钟、歌词与通知 toast 等模式间切换。抢占规则见下文。"
                },
                {
                    name: "Left",
                    text: "左侧栏：time（计时）、system（系统监视）、keys（快捷键速查）、todo（待办）。"
                },
                {
                    name: "Right",
                    text: "右侧栏：wifi、bluetooth、audio、update。"
                },
                {
                    name: "通知中心",
                    text: "通知历史与免打扰等管理界面。短时提示亦可经通知链路以 toast 形式进入 Island。"
                },
                {
                    name: "App",
                    text: "应用启动器：检索与启动桌面应用；部分应用使用内置标识资源。"
                },
                {
                    name: "WebSearch",
                    text: "独立搜索条：引擎切换、建议列表，确认后交由系统打开目标地址。"
                },
                {
                    name: "Lock",
                    text: "会话锁屏（ext-session-lock）。壁纸模糊背景；左上天气、右上通知、中轴时钟与密码；底中方案 B 媒体条（音量内嵌）。触发：Super+L、wlogout、IPC lock.lock。已替掉 hyprlock。"
                },
                {
                    name: "剪贴板",
                    text: "剪贴板历史浏览与回贴；底层依赖 cliphist 等会话侧能力。"
                }
            ]
        },
        {
            title: "Island 抢占",
            body: "一级岛在同一时刻只呈现一种主模式。优先级自高至低如下；计时结束、截图完成等事件若通过系统通知送达，则归入通知 toast 层级，不另设专用模式。",
            preempt: [
                { rank: "1", name: "Hub", text: "用户主动展开的多页面板。" },
                { rank: "2", name: "手动歌词", text: "用户固定显示的一级歌词。" },
                { rank: "3", name: "通知 toast", text: "至多堆叠三条短时通知。" },
                { rank: "4", name: "自动歌词", text: "存在播放中曲目时优先于时钟。" },
                { rank: "5", name: "时钟", text: "收起态默认内容。" }
            ]
        },
        {
            title: "数据层",
            items: [
                {
                    name: "service",
                    text: "业务单例：Network、Bluetooth、Volume、Media、Lyrics、Notification、Weather、Sysmon、Cava、Tray、Todo、Timers、Hotkeys、Updates、Lianwall 等。多为对 D-Bus、套接字或守护进程的薄封装。"
                },
                {
                    name: "state",
                    text: "跨表面共享状态与设计令牌：Island 状态机，以及 Color、Size、Style 等。"
                },
                {
                    name: "freewindow",
                    text: "浮动窗口所用模型：应用索引、剪贴板列表等。"
                }
            ]
        },
        {
            title: "后端",
            items: [
                {
                    name: "Rust 守护进程",
                    text: "backend 目录中的 weatherd、sysmond 等，经缓存文件或本地通道向对应 service 提供数据。"
                },
                {
                    name: "cava",
                    text: "频谱采集链路（relay 与 reader），由 Cava 服务消费，供系统监视等界面使用。"
                },
                {
                    name: "主题管线",
                    text: "壁纸变更经 lianwall 触发 matugen，刷新 Color 等令牌并传播至各界面。"
                }
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
                text: "说明"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Text {
                Layout.fillWidth: true
                text: "模块职责、数据依赖与 Island 抢占规则。拓扑关系见「架构」页。"
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
                wrapMode: Text.WordWrap
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
                spacing: Size.spacing.lg

                Repeater {
                    model: root.sections
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Size.spacing.sm

                        Text {
                            text: modelData.title
                            font.bold: true
                            font.pixelSize: Size.fontSize.lg
                            color: Color.primary
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !!modelData.body
                            text: modelData.body || ""
                            wrapMode: Text.WordWrap
                            font.pixelSize: Size.fontSize.sm
                            color: Color.text
                            lineHeight: 1.35
                        }

                        // 抢占栈
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: !!(modelData.preempt && modelData.preempt.length)

                            Repeater {
                                model: modelData.preempt || []
                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Size.spacing.sm

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Color.withAlpha(Color.primary, 0.85)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.rank
                                            font.bold: true
                                            font.pixelSize: Size.fontSize.xsm
                                            color: Color.textOnPrimary
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.name
                                            font.bold: true
                                            font.pixelSize: Size.fontSize.sm
                                            color: Color.text
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.text
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: Size.fontSize.sm
                                            color: Color.textMuted
                                        }
                                    }
                                }
                            }
                        }

                        // 条目列表
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Size.spacing.sm
                            visible: !!(modelData.items && modelData.items.length)

                            Repeater {
                                model: modelData.items || []
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: itemCol.implicitHeight + 20
                                    radius: Size.rounding.md
                                    color: Color.surfaceHigh
                                    border.width: Style.border.width
                                    border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                                    ColumnLayout {
                                        id: itemCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        spacing: 4
                                        Text {
                                            text: modelData.name
                                            font.bold: true
                                            font.pixelSize: Size.fontSize.sm
                                            color: Color.text
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.text
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: Size.fontSize.sm
                                            color: Color.textMuted
                                            lineHeight: 1.3
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
