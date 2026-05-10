import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config

// LianClaw 空会话欢迎页：环形时钟 + 大字日期 + 时段问候 + 一言
Item {
    id: root

    property bool hasSession: false
    property bool historyLoading: false

    // ---------- 时间 ----------
    property var _now: new Date()
    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        onTriggered: root._now = new Date()
    }

    function _pad(n) { return n < 10 ? "0" + n : "" + n }
    function _hhmm(d) { return _pad(d.getHours()) + ":" + _pad(d.getMinutes()) }
    function _todayProgress(d) {
        return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400
    }
    readonly property var _weekdays: ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    function _greet(d) {
        const h = d.getHours()
        if (h < 5)  return "夜深了"
        if (h < 9)  return "早安"
        if (h < 12) return "上午好"
        if (h < 14) return "中午好"
        if (h < 18) return "下午好"
        if (h < 22) return "晚上好"
        return        "夜安"
    }
    function _sub(d) {
        const h = d.getHours()
        if (h < 5)  return "灵感也该歇会儿啦"
        if (h < 9)  return "今天也想和你聊聊"
        if (h < 12) return "需要我帮你理理思路吗？"
        if (h < 14) return "记得吃饭哦"
        if (h < 18) return "来点咖啡，再来点代码？"
        if (h < 22) return "今天辛苦啦"
        return        "夜里也陪你写代码"
    }

    // ---------- 一言 ----------
    readonly property var _fallback: [
        { text: "敲下回车，世界就开始改变。",      from: "本地" },
        { text: "今天也要做温柔的人。",            from: "本地" },
        { text: "Stay hungry, stay foolish.",     from: "Steve Jobs" },
        { text: "代码是写给人看的，顺便能跑。",    from: "本地" },
        { text: "山有顶峰，湖有彼岸，人间总值得。",from: "本地" },
        { text: "不要温和地走进那个良夜。",        from: "Dylan Thomas" },
        { text: "热爱可抵岁月漫长。",              from: "本地" },
    ]
    property string yiyanText: ""
    property string yiyanFrom: ""

    function _fetchYiyan() {
        const self = root
        const pool = _fallback
        function fb() {
            const p = pool[Math.floor(Math.random() * pool.length)]
            self.yiyanText = p.text
            self.yiyanFrom = p.from
        }
        const xhr = new XMLHttpRequest()
        xhr.open("GET", "https://v1.hitokoto.cn/?encode=json")
        xhr.timeout = 4000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { fb(); return }
            try {
                const j = JSON.parse(xhr.responseText)
                self.yiyanText = j.hitokoto || ""
                self.yiyanFrom = j.from_who && j.from_who.length > 0
                            ? (j.from_who + (j.from ? "·" + j.from : ""))
                            : (j.from || "一言")
                if (!self.yiyanText) fb()
            } catch (e) { fb() }
        }
        xhr.ontimeout = function() { fb() }
        try { xhr.send() } catch (e) { fb() }
    }

    function refresh() {
        _now = new Date()
        _fetchYiyan()
    }

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    // ---------- UI ----------
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 380)
        spacing: 16

        // 环形时钟
        Item {
            id: clockBox
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200

            readonly property real progress: root._todayProgress(root._now)

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeColor: Qt.alpha(Colorscheme.on_surface_variant, 0.20)
                    strokeWidth: 8
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: 100; startY: 12
                    PathAngleArc {
                        centerX: 100; centerY: 100
                        radiusX: 88; radiusY: 88
                        startAngle: -90
                        sweepAngle: 360
                    }
                }
            }
            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeColor: Colorscheme.primary
                    strokeWidth: 8
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 100; startY: 12
                    PathAngleArc {
                        centerX: 100; centerY: 100
                        radiusX: 88; radiusY: 88
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
                    text: root._hhmm(root._now)
                    font.family: Sizes.fontFamily
                    font.pixelSize: 38
                    font.weight: Font.Light
                    color: Colorscheme.on_surface
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.floor(clockBox.progress * 100) + "% of today"
                    font.family: Sizes.fontFamily
                    font.pixelSize: 11
                    color: Colorscheme.on_surface_variant
                    opacity: 0.7
                }
            }
        }

        // 大字日期
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Text {
                text: root._now.getDate()
                font.family: Sizes.fontFamily
                font.pixelSize: 44
                font.weight: Font.Medium
                color: Colorscheme.primary
            }
            ColumnLayout {
                spacing: 0
                Text {
                    text: (root._now.getMonth() + 1) + " 月  ·  " + root._now.getFullYear()
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    color: Colorscheme.on_surface
                }
                Text {
                    text: root._weekdays[root._now.getDay()] + "  ·  " + root._greet(root._now)
                    font.family: Sizes.fontFamily
                    font.pixelSize: 13
                    color: Colorscheme.on_surface_variant
                }
            }
        }

        // 副标题
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.hasSession
                  ? (root.historyLoading ? "加载历史中…" : "（无消息，发一句开始聊吧）")
                  : (root._sub(root._now) + " · 请在上方选择或新建会话")
            font.family: Sizes.fontFamily
            font.pixelSize: Sizes.font.sm
            color: Colorscheme.on_surface_variant
            opacity: 0.85
        }

        // 一言卡片
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: yiyanCol.implicitHeight + 24
            radius: Sizes.rounding.large
            color: Colorscheme.surface_container_low
            border.color: Colorscheme.outline_variant
            border.width: 1

            ColumnLayout {
                id: yiyanCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.yiyanText.length > 0 ? ("「 " + root.yiyanText + " 」") : "……"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface
                    lineHeight: 1.4
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.yiyanFrom.length > 0
                    text: "—— " + root.yiyanFrom
                    horizontalAlignment: Text.AlignRight
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.xs !== undefined ? Sizes.font.xs : 11
                    color: Colorscheme.on_surface_variant
                    opacity: 0.85
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh()
                hoverEnabled: true
            }
        }
    }
}
