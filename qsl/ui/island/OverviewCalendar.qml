// OverviewCalendar — 三格轮转翻页（只刷新滚出屏外的那格）
// 回当月：相邻直接滚；跨月连续轮转，避免整窗 rebuild 卡顿

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Rectangle {
    id: root

    radius: Size.rounding.lg
    color: Color.surfaceHigh

    readonly property var monthNames: [
        "一月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "十一月", "十二月"
    ]

    property int centerYear: 0
    property int centerMonth: 0
    property bool animating: false
    property int chainLeft: 0
    property int chainDir: 0

    // 三块面板轮转：order = [左/上月, 中/当月, 右/下月]
    property var order: []

    readonly property string monthLabel: {
        if (centerMonth < 1 || centerMonth > 12)
            return "—"
        return monthNames[centerMonth - 1]
    }

    // 翻页横向滑：箭头是 < >，动画却上下走，看的人会觉得点错了
    readonly property int slideSpan: Math.max(1, gridClip.width)

    // 高亮改画居中圆：整格铺底会让六行七列糊成一片色块，
    // 圆点只占格子的一部分，留白本身成为节奏。
    function cellCircle(day) {
        if (!day || !day.inMonth)
            return "transparent"
        if (day.isToday)
            return Color.primary
        if (day.isWorkday)
            return Color.withAlpha(Color.secondary, 0.22)
        if (day.isHoliday)
            return Color.withAlpha(Color.tertiary, 0.22)
        return "transparent"
    }

    function dayColor(day) {
        if (!day)
            return Color.textMuted
        if (day.isToday)
            return Color.textOnPrimary
        if (!day.inMonth)
            return Color.withAlpha(Color.textMuted, 0.35)
        if (day.isWorkday)
            return Color.secondary
        if (day.isHoliday)
            return Color.tertiary
        if (day.isWeekend)
            return Color.error
        return Color.textOnBackground
    }

    // 节气 / 节日用空心圆标记。数字改主色行不通——主色和周末的红太近，
    // 「有节日」会被读成「是周末」。描边复用格子里那个圆，不增加元素。
    function cellOutline(day) {
        if (!day || !day.inMonth || day.isToday)
            return 0
        if (day.isHoliday || day.isWorkday)
            return 0
        return (day.label && day.label.length > 0) ? 1 : 0
    }

    // 右上角角标。假期标「假」、调休标「班」，颜色与格子圆一致
    function cornerBadge(day) {
        if (!day || !day.inMonth)
            return ""
        if (day.isWorkday)
            return "班"
        if (day.isHoliday)
            return "假"
        return ""
    }

    function badgeColor(day) {
        if (!day)
            return "transparent"
        if (day.isToday)
            return Color.textOnPrimary
        if (day.isWorkday)
            return Color.secondary
        return Color.tertiary
    }

    readonly property bool onCurrentMonth: {
        const d = Time.rawDate
        if (!d || centerYear <= 0)
            return true
        return d.getFullYear() === centerYear && (d.getMonth() + 1) === centerMonth
    }

    // 圆形翻页钮，呼应格子里的圆
    component NavButton: Rectangle {
        id: nav
        property string glyph: ""
        signal tapped

        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: width / 2
        color: navMa.containsMouse ? Color.withAlpha(Color.primary, 0.18) : Color.surfaceHighest
        opacity: root.animating ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: 140 } }

        // 填满整个圆再居中，而不是让 Text 的紧包围盒去居中——
        // 字形本身的左右边距不对称，包围盒居中看着就是偏的
        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: nav.glyph
            color: Color.primary
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.md
        }
        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.animating
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.tapped()
        }
    }

    function panelAt(i) {
        return order.length === 3 ? order[i] : null
    }

    function layoutPanels(offsetX) {
        const w = slideSpan
        const o = offsetX || 0
        const left = panelAt(0)
        const mid = panelAt(1)
        const right = panelAt(2)
        if (!left || !mid || !right)
            return
        left.x = -w + o
        mid.x = 0 + o
        right.x = w + o
    }

    function fillPanel(panel, year, month) {
        if (!panel)
            return
        panel.year = year
        panel.month = month
        panel.days = Calendar.buildDays(year, month)
    }

    function syncCenterFromMid() {
        const mid = panelAt(1)
        if (!mid)
            return
        centerYear = mid.year
        centerMonth = mid.month
        Calendar.setMonth(centerYear, centerMonth, false)
    }

    function bootstrap(year, month) {
        const p = Calendar.shiftMonth(year, month, -1)
        const n = Calendar.shiftMonth(year, month, 1)
        order = [panelA, panelB, panelC]
        fillPanel(panelA, p.year, p.month)
        fillPanel(panelB, year, month)
        fillPanel(panelC, n.year, n.month)
        centerYear = year
        centerMonth = month
        Calendar.setMonth(year, month, false)
        slideOffset = 0
        layoutPanels(0)
    }

    property real slideOffset: 0
    property real _slideFrom: 0
    property real _slideTo: 0

    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideOffset"
        duration: 260
        easing.type: Easing.OutCubic
        onStopped: root.onSlideFinished()
    }

    onSlideOffsetChanged: layoutPanels(slideOffset)

    function navigate(dir) {
        if (root.animating || slideSpan <= 1)
            return false
        root.animating = true
        root.chainDir = dir
        _slideFrom = slideOffset
        _slideTo = dir > 0 ? -slideSpan : slideSpan
        slideAnim.from = _slideFrom
        slideAnim.to = _slideTo
        slideAnim.duration = root.chainLeft > 0 ? 180 : 260
        slideAnim.start()
        return true
    }

    function recycleAfterSlide(dir) {
        // 滚完后：屏幕上已是邻月那一格；把它留在中间，只给翻到背面的格换数据
        let left = panelAt(0)
        let mid = panelAt(1)
        let right = panelAt(2)
        if (!left || !mid || !right)
            return

        if (dir > 0) {
            // 向左滚：right 成为新 mid；旧 left 去右边接再下一月
            order = [mid, right, left]
            const next = Calendar.shiftMonth(right.year, right.month, 1)
            fillPanel(left, next.year, next.month)
        } else {
            // 向右滚：left 成为新 mid；旧 right 去左边接再上一月
            order = [right, left, mid]
            const prev = Calendar.shiftMonth(left.year, left.month, -1)
            fillPanel(right, prev.year, prev.month)
        }

        slideOffset = 0
        layoutPanels(0)
        syncCenterFromMid()
    }

    function onSlideFinished() {
        recycleAfterSlide(root.chainDir)

        // 连续回当月：保持 animating，直接接下一段，避免松手闪烁
        if (root.chainLeft > 1) {
            root.chainLeft -= 1
            slideAnim.from = 0
            slideAnim.to = root.chainDir > 0 ? -slideSpan : slideSpan
            slideAnim.duration = 170
            slideAnim.start()
            return
        }

        root.chainLeft = 0
        root.chainDir = 0
        root.animating = false
    }

    function goToday() {
        if (root.animating)
            return
        const now = new Date()
        const ty = now.getFullYear()
        const tm = now.getMonth() + 1
        if (ty === centerYear && tm === centerMonth)
            return

        const delta = (ty - centerYear) * 12 + (tm - centerMonth)
        const dir = delta > 0 ? 1 : -1
        const steps = Math.abs(delta)

        if (steps === 1) {
            navigate(dir)
            return
        }

        // 跨太远直接落当月；中等距离连续轮转
        if (steps > 18) {
            bootstrap(ty, tm)
            return
        }
        root.chainLeft = steps
        root.chainDir = dir
        navigate(dir)
    }

    component MonthPanel: Item {
        id: panel
        property int year: 0
        property int month: 0
        property var days: []

        width: gridClip.width
        height: gridClip.height

        GridLayout {
            anchors.fill: parent
            columns: 7
            rows: 6
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: panel.days

                Item {
                    id: cell
                    required property var modelData
                    readonly property var dayData: modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // 节日名优先，没有就退回农历。每格都有第二行，
                    // 数字的位置才是恒定的，不会因为有没有节日而跳动
                    readonly property string festival:
                        (cell.dayData.inMonth && cell.dayData.label && !cell.dayData.isWorkday)
                        ? String(cell.dayData.label) : ""
                    readonly property string subText:
                        cell.festival.length > 0 ? cell.festival : (cell.dayData.lunar || "")

                    // 圆的直径取格子短边的八成，格子再怎么被拉伸都不会变椭圆
                    readonly property real dotSize: Math.min(width, height) * 0.86

                    Rectangle {
                        anchors.centerIn: parent
                        width: cell.dotSize
                        height: cell.dotSize
                        radius: width / 2
                        color: root.cellCircle(cell.dayData)
                        border.width: root.cellOutline(cell.dayData)
                        border.color: Color.withAlpha(Color.primary, 0.5)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -7
                        text: String(cell.dayData.day)
                        color: root.dayColor(cell.dayData)
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.lg
                        font.bold: cell.dayData.isToday || cell.dayData.isHoliday
                    }

                    Text {
                        visible: cell.subText.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 9
                        width: cell.dotSize
                        text: cell.subText
                        color: {
                            if (cell.dayData.isToday)
                                return Color.textOnPrimary
                            if (!cell.dayData.inMonth)
                                return Color.withAlpha(Color.textMuted, 0.3)
                            // 节日用强调色把自己从一片农历小字里拎出来
                            return cell.festival.length > 0
                                ? Color.tertiary
                                : Color.withAlpha(Color.textMuted, 0.75)
                        }
                        font.family: Size.fontSans
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    // 角标压在圆的右上，不与数字抢中心
                    Text {
                        readonly property string badge: root.cornerBadge(cell.dayData)
                        visible: badge.length > 0
                        text: badge
                        x: parent.width / 2 + cell.dotSize * 0.26
                        y: parent.height / 2 - cell.dotSize * 0.54
                        color: root.badgeColor(cell.dayData)
                        font.family: Size.fontSans
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: Size.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            // 月份不再套药丸底：标题本来就是标题，给它加个色块只是噪声
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                Row {
                    id: titleRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // 大的那个定基线，小的来对齐。反过来会把 26px 的月份
                    // 吊到 14px 年份的基线上，整块字就浮起来了
                    Text {
                        id: monthText
                        text: root.monthLabel
                        color: Color.textOnBackground
                        font.family: Size.fontSans
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        anchors.baseline: monthText.baseline
                        text: root.centerYear > 0 ? String(root.centerYear) : ""
                        color: Color.textMuted
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.md
                    }
                }
            }

            // 只在离开当月时出现：平时它是废话，跨月时它是唯一的回程票
            NavButton {
                visible: !root.onCurrentMonth
                glyph: "\uf192"
                onTapped: root.goToday()
            }

            NavButton {
                glyph: "\uf053"
                onTapped: root.navigate(-1)
            }

            NavButton {
                glyph: "\uf054"
                onTapped: root.navigate(1)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 0

            Repeater {
                model: [
                    { t: "日", weekend: true },
                    { t: "一", weekend: false },
                    { t: "二", weekend: false },
                    { t: "三", weekend: false },
                    { t: "四", weekend: false },
                    { t: "五", weekend: false },
                    { t: "六", weekend: true }
                ]
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        color: modelData.weekend ? Color.error : Color.textMuted
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                        opacity: modelData.weekend ? 0.95 : 0.85
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.surfaceHighest
        }

        Item {
            id: gridClip
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            onWidthChanged: {
                if (width > 0)
                    layoutPanels(slideOffset)
            }
            onHeightChanged: layoutPanels(slideOffset)

            MonthPanel { id: panelA }
            MonthPanel { id: panelB }
            MonthPanel { id: panelC }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Color.surfaceHighest
        }

        // 今日条：格子里塞不下的完整信息落在这儿。假期倒数是纯派生值，
        // 数据加载完算一次就静止，没有 Timer
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            Text {
                id: todayLine
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const t = Time.rawDate
                    if (!t)
                        return ""
                    const wd = ["日", "一", "二", "三", "四", "五", "六"][t.getDay()]
                    const l = Calendar.todayLunar
                    // 农历必须带前缀：不标注的话「六月二十」紧挨着「8月2日」，
                    // 月份对不上，看着就像日期算错了
                    return Qt.formatDateTime(t, "M月d日") + " 周" + wd
                        + (l.length > 0 ? " · 农历" + l : "")
                }
                color: Color.text
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.sm
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                readonly property var nh: Calendar.nextHoliday
                visible: !!nh
                text: {
                    if (!nh)
                        return ""
                    if (nh.daysAway <= 0)
                        return nh.name + "假期中"
                    return "距 " + nh.name + " " + nh.daysAway + " 天"
                }
                color: Color.primary
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.sm
                font.bold: true
            }
        }
    }

    Component.onCompleted: {
        const now = new Date()
        if (Calendar.displayYear > 0)
            bootstrap(Calendar.displayYear, Calendar.displayMonth)
        else
            bootstrap(now.getFullYear(), now.getMonth() + 1)
    }

    Connections {
        target: Calendar
        function onSourceTitleChanged() {
            if (root.animating)
                return
            if (root.centerYear > 0)
                root.bootstrap(root.centerYear, root.centerMonth)
        }
    }
}
