// TimePage — 时间 / 问候 / 一言（原 LcWelcomeView，无 LianClaw）
// 显示按分钟节流（环/文案不跟秒钟抖）；一言仅本页存活时 XHR，销毁时 abort
//
// 性能：无会话列表；Shape 双环；无常驻秒级 UI 重绘

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.data.service
import qs.data.state

Item {
    id: root

    // 环与问候只跟「分钟」走，避免 Time 每秒通知带动 PathAngleArc 重算
    property var now: Time.rawDate
    property int _minuteKey: -1

    readonly property var weekdays: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    readonly property var fallbackPool: [
        { text: "敲下回车，世界就开始改变。", from: "本地" },
        { text: "今天也要做温柔的人。", from: "本地" },
        { text: "Stay hungry, stay foolish.", from: "Steve Jobs" },
        { text: "代码是写给人看的，顺便能跑。", from: "本地" },
        { text: "山有顶峰，湖有彼岸，人间总值得。", from: "本地" },
        { text: "不要温和地走进那个良夜。", from: "Dylan Thomas" },
        { text: "热爱可抵岁月漫长。", from: "本地" }
    ]

    property string yiyanText: ""
    property string yiyanFrom: ""
    property var _xhr: null
    property bool _timerExpanded: false

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function hhmm(d) {
        if (!d)
            return "--:--"
        return pad(d.getHours()) + ":" + pad(d.getMinutes())
    }

    function todayProgress(d) {
        if (!d)
            return 0
        return (d.getHours() * 60 + d.getMinutes()) / (24 * 60)
    }

    function greet(d) {
        if (!d)
            return ""
        const h = d.getHours()
        if (h < 5)
            return "夜深了"
        if (h < 9)
            return "早安"
        if (h < 12)
            return "上午好"
        if (h < 14)
            return "中午好"
        if (h < 18)
            return "下午好"
        if (h < 22)
            return "晚上好"
        return "夜安"
    }

    function subline(d) {
        if (!d)
            return ""
        const h = d.getHours()
        if (h < 5)
            return "灵感也该歇会儿啦"
        if (h < 9)
            return "今天也想和你聊聊"
        if (h < 12)
            return "需要我帮你理理思路吗？"
        if (h < 14)
            return "记得吃饭哦"
        if (h < 18)
            return "来点咖啡，再来点代码？"
        if (h < 22)
            return "今天辛苦啦"
        return "夜里也陪你写代码"
    }

    function syncClock() {
        const d = Time.rawDate
        if (!d)
            return
        const key = d.getHours() * 60 + d.getMinutes()
        if (key === root._minuteKey)
            return
        root._minuteKey = key
        root.now = d
    }

    function abortYiyan() {
        const x = root._xhr
        root._xhr = null
        if (!x)
            return
        try {
            x.onreadystatechange = function() {}
            x.ontimeout = function() {}
            x.abort()
        } catch (e) {}
    }

    function fetchYiyan() {
        abortYiyan()
        const self = root
        const pool = root.fallbackPool
        function fb() {
            const p = pool[Math.floor(Math.random() * pool.length)]
            self.yiyanText = p.text
            self.yiyanFrom = p.from
        }
        const xhr = new XMLHttpRequest()
        root._xhr = xhr
        xhr.open("GET", "https://v1.hitokoto.cn/?encode=json")
        xhr.timeout = 4000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (root._xhr !== xhr)
                return
            root._xhr = null
            if (xhr.status !== 200) {
                fb()
                return
            }
            try {
                const j = JSON.parse(xhr.responseText)
                self.yiyanText = j.hitokoto || ""
                self.yiyanFrom = j.from_who && j.from_who.length > 0
                    ? (j.from_who + (j.from ? "·" + j.from : ""))
                    : (j.from || "一言")
                if (!self.yiyanText)
                    fb()
            } catch (e) {
                fb()
            }
        }
        xhr.ontimeout = function() {
            if (root._xhr !== xhr)
                return
            root._xhr = null
            fb()
        }
        try {
            xhr.send()
        } catch (e) {
            root._xhr = null
            fb()
        }
    }

    function refresh() {
        syncClock()
        fetchYiyan()
    }

    Connections {
        target: Time
        function onRawDateChanged() { root.syncClock() }
    }

    Component.onCompleted: refresh()
    Component.onDestruction: abortYiyan()

    ColumnLayout {
        id: mainCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root._timerExpanded ? -(timerPanel.height + 8) / 2 : 0
        width: Math.min(parent.width - 24, 380)
        spacing: Size.spacing.md

        Item {
            id: clockBox
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200

            readonly property real progress: root.todayProgress(root.now)

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeColor: Color.withAlpha(Color.textMuted, 0.20)
                    strokeWidth: 8
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: 100
                    startY: 12
                    PathAngleArc {
                        centerX: 100
                        centerY: 100
                        radiusX: 88
                        radiusY: 88
                        startAngle: -90
                        sweepAngle: 360
                    }
                }
            }
            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeColor: Color.primary
                    strokeWidth: 8
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 100
                    startY: 12
                    PathAngleArc {
                        centerX: 100
                        centerY: 100
                        radiusX: 88
                        radiusY: 88
                        startAngle: -90
                        sweepAngle: 360 * clockBox.progress
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.hhmm(root.now)
                    font.family: Size.fontSans
                    font.pixelSize: 38
                    font.weight: Font.Light
                    color: Color.text
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.floor(clockBox.progress * 100) + "% of today"
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                    color: Color.textMuted
                    opacity: 0.7
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Size.spacing.md

            Text {
                text: root.now ? root.now.getDate() : "-"
                font.family: Size.fontSans
                font.pixelSize: 44
                font.weight: Font.Medium
                color: Color.primary
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: root.now
                        ? ((root.now.getMonth() + 1) + " 月  ·  " + root.now.getFullYear())
                        : ""
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    color: Color.text
                }
                Text {
                    text: root.now
                        ? (root.weekdays[root.now.getDay()] + "  ·  " + root.greet(root.now))
                        : ""
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    color: Color.textMuted
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.subline(root.now)
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.sm
            color: Color.textMuted
            opacity: 0.85
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: yiyanCol.implicitHeight + 24
            radius: Size.rounding.lg
            color: Color.surface
            border.color: Color.outlineVariant
            border.width: 1

            ColumnLayout {
                id: yiyanCol
                anchors.fill: parent
                anchors.margins: Size.spacing.md
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.yiyanText.length > 0 ? ("「 " + root.yiyanText + " 」") : "……"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    color: Color.text
                    lineHeight: 1.4
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.yiyanFrom.length > 0
                    text: "—— " + root.yiyanFrom
                    horizontalAlignment: Text.AlignRight
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xsm
                    color: Color.textMuted
                    opacity: 0.85
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.refresh()
            }
        }

    }

    // ============================================================
    // 计时器面板（固定底部，不影响圆盘居中）
    // ============================================================

    Rectangle {
        id: timerPanel
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Size.spacing.sm
        // 高度 = 内容 + 上下 padding（不要 anchors.fill 子布局，否则 implicitHeight 失真）
        height: timerCol.implicitHeight + Size.spacing.md * 2 + Size.spacing.sm
        radius: Size.rounding.lg
        color: Color.surface
        border.color: Color.outlineVariant
        border.width: 1
        visible: root._timerExpanded

        ColumnLayout {
            id: timerCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Size.spacing.md
            spacing: Size.spacing.sm

            // 标题行 + 收起
            RowLayout {
                Layout.fillWidth: true
                spacing: Size.spacing.sm
                Text {
                    text: "计时"
                    font.pixelSize: Size.fontSize.sm
                    font.bold: true
                    color: Color.text
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "收起 ▲"
                    color: collapseMa.containsMouse ? Color.primary : Color.textMuted
                    font.pixelSize: Size.fontSize.xsm
                    Layout.alignment: Qt.AlignVCenter
                    MouseArea {
                        id: collapseMa
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._timerExpanded = false
                    }
                }
            }

            // ---- 秒表 ----
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.sm
                Text { text: "\ue425"; font.family: Size.fontIcon; font.pixelSize: Size.fontSize.lg; color: Color.primary; Layout.alignment: Qt.AlignVCenter }
                Text { text: "秒表"; font.pixelSize: Size.fontSize.sm; font.bold: true; color: Color.text; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Text { text: Timers.formatSec(Timers.stopwatch.elapsed); font.family: Size.fontMono; font.pixelSize: Size.fontSize.lg; color: Timers.stopwatch.running ? Color.primary : Color.text; Layout.alignment: Qt.AlignVCenter }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                    color: Timers.stopwatch.running ? Color.withAlpha(Color.error, 0.15) : Color.withAlpha(Color.primary, 0.15)
                    Text { anchors.centerIn: parent; text: Timers.stopwatch.running ? "暂停" : "开始"; color: Timers.stopwatch.running ? Color.error : Color.primary; font.pixelSize: Size.fontSize.xsm; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.stopwatch.running ? Timers.pauseStopwatch() : Timers.startStopwatch() }
                }
                Rectangle {
                    visible: Timers.stopwatch.elapsed > 0 && !Timers.stopwatch.running
                    Layout.preferredWidth: 52; Layout.preferredHeight: 28; radius: Size.rounding.sm; color: Color.withAlpha(Color.text, 0.06)
                    Text { anchors.centerIn: parent; text: "重置"; color: Color.textMuted; font.pixelSize: Size.fontSize.xsm }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.resetStopwatch() }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Color.withAlpha(Color.outlineVariant, 0.3) }

            // ---- 倒计时 ----
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.sm
                Text { text: "\ue88b"; font.family: Size.fontIcon; font.pixelSize: Size.fontSize.lg; color: Color.primary; Layout.alignment: Qt.AlignVCenter }
                Text { text: "倒计时"; font.pixelSize: Size.fontSize.sm; font.bold: true; color: Color.text; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.fillWidth: true }
                Text { text: Timers.formatSec(Timers.countdown.remaining); font.family: Size.fontMono; font.pixelSize: Size.fontSize.lg; color: Timers.countdown.running ? Color.primary : Color.text; Layout.alignment: Qt.AlignVCenter }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                visible: !Timers.countdown.running && Timers.countdown.remaining <= 0
                Repeater {
                    model: [{ label: "1分", secs: 60 }, { label: "5分", secs: 300 }, { label: "15分", secs: 900 }, { label: "25分", secs: 1500 }]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                        color: cdMa.containsMouse ? Color.withAlpha(Color.primary, 0.15) : Color.withAlpha(Color.text, 0.06)
                        Text { anchors.centerIn: parent; text: modelData.label; color: cdMa.containsMouse ? Color.primary : Color.textMuted; font.pixelSize: Size.fontSize.xsm; font.bold: cdMa.containsMouse }
                        MouseArea { id: cdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Timers.startCountdown(modelData.secs) }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: Size.spacing.xs
                visible: Timers.countdown.running || Timers.countdown.remaining > 0
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Size.rounding.sm
                    color: Timers.countdown.running ? Color.withAlpha(Color.error, 0.15) : Color.withAlpha(Color.primary, 0.15)
                    Text { anchors.centerIn: parent; text: Timers.countdown.running ? "暂停" : "继续"; color: Timers.countdown.running ? Color.error : Color.primary; font.pixelSize: Size.fontSize.xsm; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.countdown.running ? Timers.pauseCountdown() : Timers.startCountdown(0) }
                }
                Rectangle {
                    Layout.preferredWidth: 52; Layout.preferredHeight: 28; radius: Size.rounding.sm; color: Color.withAlpha(Color.text, 0.06)
                    Text { anchors.centerIn: parent; text: "重置"; color: Color.textMuted; font.pixelSize: Size.fontSize.xsm }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Timers.resetCountdown() }
                }
            }
        }
    }

    // 展开按钮（面板隐藏时）
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Size.spacing.sm
        width: 120; height: 28; radius: Size.rounding.full
        color: ttMa.containsMouse ? Color.withAlpha(Color.text, 0.06) : "transparent"
        visible: !root._timerExpanded
        Text { anchors.centerIn: parent; text: "计时器 ▼"; color: Color.textMuted; font.pixelSize: Size.fontSize.xsm }
        MouseArea { id: ttMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root._timerExpanded = true }
    }
}
