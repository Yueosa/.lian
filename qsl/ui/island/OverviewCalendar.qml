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
        return monthNames[centerMonth - 1] + "  ·  " + centerYear
    }

    readonly property int gridH: Math.max(1, gridClip.height)

    function cellBackground(day) {
        if (!day)
            return "transparent"
        if (day.isToday)
            return Color.primary
        if (day.isWorkday)
            return Color.withAlpha(Color.secondary, 0.20)
        if (day.isHoliday)
            return Color.withAlpha(Color.tertiary, 0.22)
        if (day.label && day.label.length > 0 && day.inMonth)
            return Color.withAlpha(Color.primary, 0.12)
        if (day.inMonth && day.isWeekend)
            return Color.withAlpha(Color.error, 0.08)
        return "transparent"
    }

    function dayColor(day) {
        if (!day)
            return Color.textMuted
        if (day.isToday)
            return Color.textOnPrimary
        if (!day.inMonth)
            return Color.withAlpha(Color.textMuted, 0.45)
        if (day.isWorkday)
            return Color.secondary
        if (day.isHoliday)
            return Color.tertiary
        if (day.isWeekend)
            return Color.error
        return Color.textOnBackground
    }

    function shortLabel(day) {
        if (!day || !day.label)
            return ""
        if (day.isWorkday)
            return "班"
        return String(day.label)
    }

    function panelAt(i) {
        return order.length === 3 ? order[i] : null
    }

    function layoutPanels(offsetY) {
        const h = gridH
        const o = offsetY || 0
        const left = panelAt(0)
        const mid = panelAt(1)
        const right = panelAt(2)
        if (!left || !mid || !right)
            return
        left.y = -h + o
        mid.y = 0 + o
        right.y = h + o
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
        if (root.animating || gridH <= 1)
            return false
        root.animating = true
        root.chainDir = dir
        _slideFrom = slideOffset
        _slideTo = dir > 0 ? -gridH : gridH
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
            // 向上滚：right 成为新 mid；旧 left 去右边接再下一月
            order = [mid, right, left]
            const next = Calendar.shiftMonth(right.year, right.month, 1)
            fillPanel(left, next.year, next.month)
        } else {
            // 向下滚：left 成为新 mid；旧 right 去左边接再上一月
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
            slideAnim.to = root.chainDir > 0 ? -gridH : gridH
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

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Size.rounding.sm
                        color: root.cellBackground(cell.dayData)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: root.shortLabel(cell.dayData).length > 0 ? -7 : 0
                        text: String(cell.dayData.day)
                        color: root.dayColor(cell.dayData)
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.lg
                        font.bold: cell.dayData.isToday || cell.dayData.isHoliday || cell.dayData.isWeekend
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: parent.width - 6
                        visible: root.shortLabel(cell.dayData).length > 0 && cell.dayData.inMonth
                        text: root.shortLabel(cell.dayData)
                        color: cell.dayData.isToday ? Color.textOnPrimary : root.dayColor(cell.dayData)
                        font.family: Size.fontSans
                        font.pixelSize: Size.fontSize.xsm
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        opacity: 0.9
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: Size.rounding.lg
                color: Color.surfaceHighest

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    verticalAlignment: Text.AlignVCenter
                    text: root.monthLabel
                    color: Color.textOnBackground
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.xl
                    font.bold: true
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }
            }

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 48
                radius: Size.rounding.lg
                color: Color.surfaceHighest
                opacity: root.animating ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: "\uf053"
                    color: Color.primary
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.lg
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.animating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate(-1)
                }
            }

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 48
                radius: Size.rounding.lg
                color: Color.surfaceHighest
                opacity: root.animating ? 0.5 : 1

                Text {
                    anchors.centerIn: parent
                    text: "\uf054"
                    color: Color.primary
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.lg
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.animating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigate(1)
                }
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

            onWidthChanged: layoutPanels(slideOffset)
            onHeightChanged: {
                if (height > 0)
                    layoutPanels(slideOffset)
            }

            MonthPanel { id: panelA }
            MonthPanel { id: panelB }
            MonthPanel { id: panelC }
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
