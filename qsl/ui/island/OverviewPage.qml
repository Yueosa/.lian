// OverviewPage — Hub Overview：身份卡 + 天气条 + 通知/待办/计时器聚合 + 右日历
//
// 性能：hostname/uptime 是 oneshot Process；聚合区全部读现成单例的
// 派生属性（Notification.count / Todo.count / Timers.*），本页不新建
// 任何 Timer、不做轮询。倒计时运行时每秒一次文本更新，是 Timers 自己
// 的 tick 带来的，本页只是多挂一个绑定。切 Tab 随 Loader 整体销毁。

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    property string hostname: "localhost"
    property string uptimeText: "—"

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

    function restartQs() {
        const wd = Quickshell.env("WAYLAND_DISPLAY") || "wayland-1"
        const xdg = Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
        const dbus = Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""
        let cmd = "pkill -x qs; sleep 0.5; "
            + "export WAYLAND_DISPLAY=" + wd + "; "
            + "export XDG_RUNTIME_DIR=" + xdg + "; "
        if (dbus)
            cmd += "export DBUS_SESSION_BUS_ADDRESS='" + dbus + "'; "
        cmd += "MALLOC_CONF=background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000 "
            + "QSG_RENDER_LOOP=basic qs -d -n >/tmp/qsl_restart.log 2>&1 &"
        Quickshell.execDetached(["bash", "-lc", cmd])
    }

    // 小标签：Arch / Hyprland / Wayland
    component Tag: Rectangle {
        property string label: ""
        implicitWidth: tagText.implicitWidth + 14
        implicitHeight: 20
        radius: height / 2
        color: Color.withAlpha(Color.primary, 0.14)

        Text {
            id: tagText
            anchors.centerIn: parent
            text: parent.label
            color: Color.primary
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.xsm
        }
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

    // 未完成的前 3 项：星标优先，其次按优先级。只在 Todo.items 变时重算
    readonly property var pendingTodos: {
        const all = (Todo.items || []).filter(i => i && !i.done)
        all.sort((a, b) => {
            if (!!a.starred !== !!b.starred)
                return a.starred ? -1 : 1
            return (a.priority || 0) - (b.priority || 0)
        })
        return all.slice(0, 3)
    }

    readonly property int pendingOverflow:
        Math.max(0, (Todo.count - Todo.doneCount) - root.pendingTodos.length)

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

    function formatUptime(secs) {
        const s = Math.max(0, Math.floor(Number(secs) || 0))
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0)
            return "up " + d + "d " + h + "h"
        if (h > 0)
            return "up " + h + "h " + m + "m"
        return "up " + m + "m"
    }

    function applySysinfo(text) {
        const lines = String(text || "").trim().split("\n")
        if (lines.length >= 1 && lines[0].trim().length)
            hostname = lines[0].trim()
        if (lines.length >= 2)
            uptimeText = formatUptime(lines[1].trim())
    }

    Component.onCompleted: sysProc.running = true

    Process {
        id: sysProc
        command: [
            "sh", "-c",
            "printf '%s\\n' \"$(cat /etc/hostname 2>/dev/null)\" "
            + "\"$(cut -d. -f1 /proc/uptime 2>/dev/null)\""
        ]
        stdout: StdioCollector {
            id: sysOut
            onStreamFinished: root.applySysinfo(sysOut.text)
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 20

        // ---- 左栏 ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // 身份卡：主机名当主标题，栈标签 + uptime 副行，右上角重启
            // 开销：单 Row + OpacityMask，无额外 Binding
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 124
                radius: Size.rounding.lg
                color: Color.surfaceContainerHigh

                Row {
                    id: identityBody
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: restartBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Item {
                        width: 76
                        height: 76
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
                                font.pixelSize: Size.fontSize.hero
                                font.bold: true
                            }
                        }

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: Size.island.avatarUrl
                            sourceSize: Qt.size(128, 128)
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
                        spacing: 7

                        Text {
                            text: root.hostname
                            color: Color.backgroundText
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.xl
                            font.bold: true
                        }
                        Row {
                            spacing: 5
                            Tag { label: "Arch" }
                            Tag { label: "Hyprland" }
                            Tag { label: "Wayland" }
                        }
                        Text {
                            text: root.greetText + " · " + root.uptimeText
                            color: Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.sm
                        }
                    }
                }

                Rectangle {
                    id: restartBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.restartArmed ? restartLabel.implicitWidth + 24 : 34
                    height: 34
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

            // 天气横条 → Weather Tab
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                radius: Size.rounding.lg
                color: Color.surfaceContainerHigh

                WeatherIcon {
                    id: wIcon
                    sourceUrl: Weather.iconSource
                    pixelSize: 46
                    contentScale: 1.28
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: wTemp
                    anchors.left: wIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ready ? Weather.tempText : "--"
                    color: Color.backgroundText
                    font.family: Size.fontMono
                    font.pixelSize: 30
                    font.weight: Font.Black
                }

                // 天气与地名共用剩余宽度，地名单行截断——横条里换行会把
                // 整条撑高，两行地名也没人真的去读第二行
                Column {
                    anchors.left: wTemp.right
                    anchors.leftMargin: 12
                    anchors.right: wChevron.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        visible: Weather.ready && Weather.weatherText.length > 0
                        text: Weather.weatherText
                        color: Color.text
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: Weather.ready
                            ? (Weather.locationName || "未知地点")
                            : "天气加载中…"
                        color: Color.textMuted
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.sm
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: wChevron
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf054"
                    color: Color.textMuted
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.lg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.hubTabIndex = 3
                }

                Component.onCompleted: Weather.ensureDaemon()
            }

            // 待办卡：Todo.items 常驻内存，列真实条目是免费的。
            // 通知只给计数——entries 仅在通知面板打开时维护，为了在这儿
            // 显示标题而把它钉住不放，等于把之前省下的内存又还回去
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Size.rounding.lg
                color: Color.surfaceContainerHigh

                Column {
                    id: todoBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "待办"
                            color: Color.backgroundText
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.md
                            font.bold: true
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Todo.count > 0
                                ? Todo.doneCount + " / " + Todo.count
                                : "空"
                            color: Color.textMuted
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.sm
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
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

                    Repeater {
                        model: root.pendingTodos
                        delegate: Item {
                            required property var modelData
                            width: todoBody.width
                            height: 30

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
                                anchors.verticalCenter: parent.verticalCenter
                                width: tagLabel.implicitWidth + 12
                                height: 18
                                radius: height / 2
                                color: Color.withAlpha(Color.secondary, 0.16)
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
                    }

                    Text {
                        width: parent.width
                        visible: root.pendingOverflow > 0
                        text: "还有 " + root.pendingOverflow + " 项未完成"
                        color: Color.textMuted
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                    }

                    Text {
                        width: parent.width
                        visible: Todo.count > 0 && root.pendingTodos.length === 0
                        text: "全部完成"
                        color: Color.primary
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.sm
                    }
                }

                // 通知与计时器压到卡片底部，不跟待办抢视觉重心
                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    spacing: 8

                    MiniStat {
                        glyph: "\uf0f3"
                        accent: !Notification.dndEnabled && Notification.count > 0
                        text: Notification.dndEnabled
                            ? "免打扰"
                            // entries 上限 80，到顶就不是精确值了
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

        // 定宽：日历是参考物不是主角，让它按内容取宽度，剩下的给左栏
        OverviewCalendar {
            Layout.preferredWidth: 400
            Layout.fillWidth: false
            Layout.fillHeight: true
        }
    }
}
