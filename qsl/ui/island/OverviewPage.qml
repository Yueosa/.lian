// OverviewPage — Hub Overview：身份 + 时钟并排，天气横条，待办只读可滚，右日历
//
// 高度预算（overviewHeight 452，减 margins 16 = 436 可用）：
//   左栏  身份/时钟条 96 + 10 + 天气横条 66 + 10 + 待办卡 254
//   待办卡内 margins 28 + 标题 19 + 4 进度 + 小状态 32 + 三段间距 24 = 107
//         → 列表净高 147，按 30 一行看到 5 条，再多靠滚
//   右栏  日历 436（内部预算见 OverviewCalendar 顶部）
// 改这里的数之前先把两栏的和重算一遍——比内容矮就会有卡片被顶出岛外。
//
// 性能：本页不起进程、不建 Timer、不做轮询，全部读现成单例
// （Sysmon.hostname / uptimeText、Battery、Notification.count、Todo.count、
// Timers.*）。切 Tab 随 Loader 整体销毁。
// hostname/uptime 原先是本页自起的 oneshot Process，第 9 轮搬进 Sysmon。

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    readonly property string hostname: Sysmon.hostname || "localhost"
    // Sysmon.uptimeText 不带前缀（系统页那边是单独一格标签），这儿要拼进身份行
    readonly property string uptimeText: Sysmon.uptimeSecs > 0
        ? "up " + Sysmon.uptimeText
        : "—"

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property string avatarLetter: userName.length > 0
        ? userName.charAt(0).toUpperCase()
        : "?"

    // 重启是不可逆操作，误触等于把整个 shell 打没。点第一下只是上膛，
    // 3 秒内不补第二下就自动退回
    property bool restartArmed: false

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.restartArmed = false
    }

    // 真正怎么重启在 Session.restartShell()——那里存着按 PID 而不是进程名去杀的
    // 缘由。这儿只管上膛与退回。
    function restartQs() {
        Session.restartShell()
    }

    // 卡片底部的小状态块：图标 + 一句话
    component MiniStat: Rectangle {
        property string glyph: ""
        property string text: ""
        property bool accent: false

        width: (parent.width - parent.spacing) / 2
        height: 32
        radius: Size.rounding.md
        color: accent ? Color.withAlpha(Color.primary, 0.12) : Color.surfaceContainerHighest

        Row {
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.glyph
                color: parent.parent.accent ? Color.primary : Color.textMuted
                font.family: Size.fontMono
                font.pixelSize: Size.fontSize.sm
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                color: parent.parent.accent ? Color.primary : Color.textMuted
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.sm
                font.bold: parent.parent.accent
            }
        }
    }

    // 未完成全部：星标优先，其次按优先级。只读可滚，不截断
    readonly property var pendingTodos: {
        void Todo.revision
        const all = (Todo.items || []).filter(i => i && !i.done)
        all.sort((a, b) => {
            if (!!a.starred !== !!b.starred)
                return a.starred ? -1 : 1
            return (a.priority || 0) - (b.priority || 0)
        })
        return all
    }

    readonly property string batteryText: {
        if (!Battery.isPresent)
            return ""
        const pct = Math.round(Battery.percentage)
        if (Battery.charging)
            return pct + "% 充电"
        if (Battery.fullyCharged)
            return pct + "% 满电"
        return pct + "%"
    }

    readonly property string greetText: {
        const d = Time.rawDate
        const hr = d ? d.getHours() : 0
        if (hr < 5) return "夜深了"
        if (hr < 9) return "早安"
        if (hr < 12) return "上午好"
        if (hr < 14) return "中午好"
        if (hr < 18) return "下午好"
        if (hr < 22) return "晚上好"
        return "夜安"
    }

    Component.onCompleted: Sysmon.refreshBasics()

    component StatPill: Rectangle {
        property string text: ""
        property bool accent: false
        visible: text.length > 0
        implicitWidth: pillText.implicitWidth + 16
        implicitHeight: 20
        radius: height / 2
        color: accent ? Color.withAlpha(Color.primary, 0.16) : Color.surfaceContainerHighest

        Text {
            id: pillText
            anchors.centerIn: parent
            text: parent.text
            color: parent.accent ? Color.primary : Color.textMuted
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.xsm
        }
    }

    QslStagger { id: stagger }
    function playEnter() { stagger.restart() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 14

        // ---- 左栏：身份+天气一条，待办吃剩下的 ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // 这一条是**定高**的，fillHeight 必须显式关掉。
            //
            // 嵌在 ColumnLayout 里的 RowLayout，Layout.fillHeight 默认是 true
            // （布局类 item 的默认值和普通 item 相反），所以光写 preferredHeight
            // 不管用：它会和下面 fillHeight 的待办卡平分剩余空间，把待办整张顶
            // 到岛外面去——上一版就是这么烂掉的
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 96
                Layout.maximumHeight: 96
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 3
                    radius: Size.rounding.lg
                    color: Color.surfaceContainerHigh
                    opacity: stagger.shown(0) ? 1 : 0
                    transform: Translate {
                        y: stagger.shown(0) ? 0 : 12
                        Behavior on y { Anim { type: Anim.Enter } }
                    }
                    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

                    Row {
                        id: identityBody
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        // 给右上角那颗重启钮让出通道：钮是 corner 定位的，
                        // 不参与 Row 的宽度计算，文字列得自己躲开，否则长
                        // hostname 会 elide 到钮底下
                        anchors.rightMargin: 44
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Item {
                            width: 56
                            height: 56
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Color.surfaceContainerHighest
                                visible: avatarImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: root.avatarLetter
                                    color: Color.primary
                                    font.family: Size.fontSans
                                    font.pixelSize: Size.fontSize.title
                                    font.bold: true
                                }
                            }

                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: Avatar.source
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                visible: false
                            }

                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: avatarImg
                                maskSource: avatarMask
                                visible: avatarImg.status === Image.Ready
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            width: Math.max(0, identityBody.width - 66)

                            Row {
                                spacing: 6
                                Text {
                                    id: hostText
                                    text: root.hostname
                                    color: Color.backgroundText
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.lg
                                    font.bold: true
                                }
                                Text {
                                    anchors.baseline: hostText.baseline
                                    text: root.greetText
                                    color: Color.textMuted
                                    font.family: Size.fontSans
                                    font.pixelSize: Size.fontSize.xsm
                                }
                            }
                            // 三个平台标签本来是三颗药丸，横着要 204px。顶条收窄
                            // 之后放不下，就跟重启钮撞在一起（第 8 轮第一版的样子）。
                            // 它们是**永不变化**的静态信息，不值得占一行药丸的宽度，
                            // 压成一行小字 145px，信息一个没少
                            Text {
                                width: parent.width
                                text: "Arch · Hyprland · Wayland"
                                color: Color.withAlpha(Color.textMuted, 0.8)
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.xsm
                                elide: Text.ElideRight
                            }
                            // 原系统页那两条（uptime / 电量）落在这儿。没电池的
                            // 机器 batteryText 是空串，StatPill 自己 visible: false
                            Row {
                                spacing: 6
                                StatPill {
                                    text: root.uptimeText
                                }
                                StatPill {
                                    text: root.batteryText
                                    accent: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: restartBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        width: root.restartArmed ? restartLabel.implicitWidth + 22 : 28
                        height: 28
                        radius: height / 2
                        color: root.restartArmed
                            ? Color.withAlpha(Color.error, 0.9)
                            : (restartHover.containsMouse ? Color.surfaceContainerHighest : "transparent")
                        border.width: root.restartArmed ? 0 : 1
                        border.color: Color.withAlpha(Color.outlineVariant, 0.6)

                        Behavior on width {
                            Anim { type: Anim.SpatialFast }
                        }

                        Text {
                            id: restartLabel
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.restartArmed ? "确认重启" : "\uf021"
                            color: root.restartArmed ? Color.primaryText : Color.textMuted
                            font.family: root.restartArmed ? Size.fontSans : Size.fontMono
                            font.pixelSize: Size.fontSize.sm
                        }

                        MouseArea {
                            id: restartHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.restartArmed) {
                                    disarm.stop()
                                    root.restartQs()
                                } else {
                                    root.restartArmed = true
                                    disarm.restart()
                                }
                            }
                        }
                    }
                }

                // 时钟。日历那张只到"日"，看时间原先得抬头去看栏——本页缺的
                // 就是这一块。秒不显示：秒针等于每秒一次重排，这页不值得
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    radius: Size.rounding.lg
                    color: Color.surfaceContainerHigh
                    opacity: stagger.shown(1) ? 1 : 0
                    transform: Translate {
                        y: stagger.shown(1) ? 0 : 12
                        Behavior on y { Anim { type: Anim.Enter } }
                    }
                    Behavior on opacity { Anim { type: Anim.EffectsSlow } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Time.hours + ":" + Time.minutes
                            color: Color.backgroundText
                            font.family: Size.fontMono
                            font.pixelSize: 36
                            font.weight: Font.Black
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                const t = Time.rawDate
                                if (!t)
                                    return ""
                                const wd = ["日", "一", "二", "三", "四", "五", "六"][t.getDay()]
                                return Qt.formatDateTime(t, "M月d日") + " 周" + wd
                            }
                            color: Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.xsm
                        }
                    }
                }
            }

            // 天气横条。原来是顶条里的一张竖卡，宽度只有 192，"奚六街道,官渡区,
            // 昆明市,云南省,中国"这种地名根本塞不进去，只能 elide 成一截乱码。
            // 地名在天气页有完整的，这里不重复；空出来的位置给体感温度——
            // 那是"要不要加件外套"的直接答案，比地名有用
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 66
                Layout.maximumHeight: 66
                radius: Size.rounding.lg
                color: Color.surfaceContainerHigh
                opacity: stagger.shown(2) ? 1 : 0
                transform: Translate {
                    y: stagger.shown(2) ? 0 : 12
                    Behavior on y { Anim { type: Anim.Enter } }
                }
                Behavior on opacity { Anim { type: Anim.EffectsSlow } }

                WeatherIcon {
                    id: wIcon
                    sourceUrl: Weather.iconSource
                    pixelSize: 42
                    contentScale: 1.28
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: tempText
                    anchors.left: wIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ready ? Weather.tempText : "--"
                    color: Color.backgroundText
                    font.family: Size.fontMono
                    font.pixelSize: 28
                    font.weight: Font.Black
                }

                Text {
                    anchors.left: tempText.right
                    anchors.leftMargin: 10
                    anchors.right: statRow.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ready ? (Weather.weatherText || "") : "天气加载中…"
                    color: Color.textMuted
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }

                // 腾出地名那块位置之后条子空了半截。补的三个都是"出门前要
                // 知道"的量：体感决定穿什么、湿度决定闷不闷、紫外线决定要不要
                // 防晒。风速/气压那种留给天气页
                Row {
                    id: statRow
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    StatPill {
                        text: Weather.ready ? ("体感 " + Weather.feelsText) : ""
                        accent: true
                    }
                    StatPill {
                        text: Weather.ready ? ("湿度 " + Weather.humidityText) : ""
                    }
                    StatPill {
                        text: Weather.ready
                            ? ("紫外线 " + Weather.uvText + " " + Weather.uvLevel)
                            : ""
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.hubTabIndex = 3
                }

                Component.onCompleted: Weather.ensureDaemon()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Size.rounding.lg
                color: Color.surfaceContainerHigh
                opacity: stagger.shown(3) ? 1 : 0
                transform: Translate {
                    y: stagger.shown(3) ? 0 : 12
                    Behavior on y { Anim { type: Anim.Enter } }
                }
                Behavior on opacity { Anim { type: Anim.EffectsSlow } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "待办"
                            color: Color.backgroundText
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.md
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Todo.count > 0
                                ? Todo.doneCount + " / " + Todo.count
                                : "空"
                            color: Color.textMuted
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.sm
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Color.surfaceContainerHighest
                        visible: Todo.count > 0

                        Rectangle {
                            width: parent.width * (Todo.count > 0
                                ? Todo.doneCount / Todo.count : 0)
                            height: parent.height
                            radius: parent.radius
                            color: Color.primary
                            Behavior on width {
                                Anim {}
                            }
                        }
                    }

                    // 只读可滚：本页不做增删改（那是 Z 面板的活），但要能看全
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.pendingTodos

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 4
                        }

                        delegate: Item {
                            required property var modelData
                            width: ListView.view.width
                            height: 28

                            Rectangle {
                                id: pri
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: modelData.starred
                                    ? Color.error
                                    : (modelData.priority <= 0 ? Color.primary
                                                               : Color.withAlpha(Color.textMuted, 0.5))
                            }
                            Text {
                                anchors.left: pri.right
                                anchors.leftMargin: 10
                                anchors.right: tagChip.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text || ""
                                color: Color.text
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.sm
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: tagChip
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: tagLabel.implicitWidth + 12
                                height: 18
                                radius: height / 2
                                color: Color.withAlpha(Color.secondary, 0.16)
                                visible: !!(modelData.tag)
                                Text {
                                    id: tagLabel
                                    anchors.centerIn: parent
                                    text: modelData.tag || ""
                                    color: Color.secondary
                                    font.family: Size.fontSans
                                    font.pixelSize: Size.fontSize.xsm
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.pendingTodos.length === 0
                            text: Todo.count > 0 ? "全部完成" : "没有待办"
                            color: Todo.count > 0 ? Color.primary : Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.sm
                        }
                    }

                    Row {
                        Layout.fillWidth: true
                        spacing: 8

                        MiniStat {
                            glyph: "\uf0f3"
                            accent: !Notification.dndEnabled && Notification.count > 0
                            text: Notification.dndEnabled
                                ? "免打扰"
                                : (Notification.count >= 80 ? "80+ 条"
                                   : (Notification.count > 0 ? Notification.count + " 条" : "无通知"))
                        }
                        MiniStat {
                            glyph: "\uf017"
                            accent: Timers.countdown.running || Timers.stopwatch.running
                            text: {
                                if (Timers.countdown.running)
                                    return "倒 " + Timers.formatSec(Timers.countdown.remaining)
                                if (Timers.stopwatch.running)
                                    return "正 " + Timers.formatSec(Timers.stopwatch.elapsed)
                                return "无计时"
                            }
                        }
                    }
                }
            }
        }

        OverviewCalendar {
            Layout.preferredWidth: 360
            Layout.fillWidth: false
            Layout.fillHeight: true
            opacity: stagger.shown(4) ? 1 : 0
            transform: Translate {
                y: stagger.shown(4) ? 0 : 12
                Behavior on y { Anim { type: Anim.Enter } }
            }
            Behavior on opacity { Anim { type: Anim.EffectsSlow } }
        }
    }
}
