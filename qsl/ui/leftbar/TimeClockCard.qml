// TimeClockCard — 时间圆盘 / 日期 / 问候 / 一言（TimePage 上半拆出的容器卡）
// 显示按分钟节流（环/文案不跟秒钟抖）；一言仅本卡存活时 XHR，销毁时 abort
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 性能：无会话列表；Shape 双环；无常驻秒级 UI 重绘

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.data.service
import qs.data.state

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: mainCol.implicitHeight + 32   // 上下各 16 留白

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
        anchors.top: parent.top
        anchors.topMargin: 16
        width: Math.min(parent.width - 32, 380)
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
            // 固定高度：一言是 XHR 异步加载，高度随内容变会让整卡突然长高
            Layout.preferredHeight: 88
            radius: Size.rounding.lg
            color: Color.surface
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
            border.width: Style.border.width
            // 实色卡面，对齐 Hub 层次（内容内层 surface，非容器背景）

            ColumnLayout {
                id: yiyanCol
                anchors.fill: parent
                anchors.margins: Size.spacing.md
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.yiyanText.length > 0 ? ("「 " + root.yiyanText + " 」") : "……"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    color: Color.text
                    lineHeight: 1.4
                    elide: Text.ElideRight
                    maximumLineCount: 2
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
}
