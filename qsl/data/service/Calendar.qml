pragma Singleton

// ============================================================
// 日历服务 — Calendar
// ============================================================
// 中国法定节假日日历。数据来自 asset/calendar/<year>.json。
// 每年更新 JSON 文件即可，无需编译。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   displayYear    int      当前显示年份
//   displayMonth   int      当前显示月份（1-12）
//   monthTitle     string   月份标题  "2026 / 7"
//   sourceTitle    string   数据来源标题
//   sourceUrl      string   数据来源 URL
//   days           model    当月日期列表 [{year,month,day,weekday,label,isHoliday,isWorkday,isToday}]
//
// 方法：
//   setMonth(year, month)   设置显示月份
//   previousMonth()         上个月
//   nextMonth()             下个月
//   resetToToday()          回到本月
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- 状态 ----
    property int displayYear: 0
    property int displayMonth: 0
    property string sourceTitle: ""
    property string sourceUrl: ""
    readonly property string monthTitle: displayYear + " / " + displayMonth

    // ---- 数据存储 ----
    property var _holidays: ({})    // "YYYY-MM-DD" → "元旦"
    property var _workdays: ({})    // "YYYY-MM-DD" → "春节调休"
    property var _festivals: ({})   // "YYYY-MM-DD" → ["节气"]
    property var _allDates: []

    function _key(y, m, d) { return y + "-" + String(m).padStart(2,'0') + "-" + String(d).padStart(2,'0') }

    // ---- 日期模型 ----
    readonly property ListModel days: ListModel {
        id: _daysModel
    }

    // ---- 加载 JSON 数据 ----
    FileView {
        id: _dataFile
        path: _resolveDataPath()

        onLoaded: {
            try {
                const json = JSON.parse(_dataFile.text());
                sourceTitle = json.sourceTitle || ""
                sourceUrl = json.sourceUrl || ""

                const h = {}, w = {}, f = {}
                for (const item of json.holidays || []) {
                    _fillRange(h, item.start, item.end, item.name)
                }
                for (const item of json.workdays || []) {
                    w[item.date] = item.name
                }
                for (const item of json.festivals || []) {
                    const d = item.date
                    if (!f[d]) f[d] = []
                    f[d].push(item.name)
                }
                root._holidays = h
                root._workdays = w
                root._festivals = f
                root._allDates = Object.keys({...h, ...w, ...f}).sort()

                resetToToday()
            } catch (e) {}
        }
    }

    function _resolveDataPath() {
        const year = new Date().getFullYear()
        const base = Qt.resolvedUrl("../../asset/calendar/")
        return base.replace("file://", "") + year + ".json"
    }

    function _fillRange(map, start, end, name) {
        const s = new Date(start)
        const e = new Date(end)
        const cur = new Date(s)
        while (cur <= e) {
            const key = _key(cur.getFullYear(), cur.getMonth()+1, cur.getDate())
            map[key] = name
            cur.setDate(cur.getDate() + 1)
        }
    }

    // ---- 构建当月日历 ----
    function setMonth(year, month) {
        displayYear = year
        displayMonth = month
        _rebuild()
    }

    function previousMonth() {
        if (displayMonth === 1) setMonth(displayYear - 1, 12)
        else setMonth(displayYear, displayMonth - 1)
    }

    function nextMonth() {
        if (displayMonth === 12) setMonth(displayYear + 1, 1)
        else setMonth(displayYear, displayMonth + 1)
    }

    function resetToToday() {
        const now = new Date()
        setMonth(now.getFullYear(), now.getMonth() + 1)
    }

    function _rebuild() {
        _daysModel.clear()
        const today = new Date()
        const todayKey = _key(today.getFullYear(), today.getMonth()+1, today.getDate())

        // 当月第一天
        const first = new Date(displayYear, displayMonth - 1, 1)
        const last = new Date(displayYear, displayMonth, 0) // 当月最后一天

        // 从上周日开始填充（补齐前导空白）
        const startDay = new Date(first)
        startDay.setDate(startDay.getDate() - first.getDay())

        // 生成 6 周 × 7 天 = 42 天
        for (let w = 0; w < 6; w++) {
            for (let d = 0; d < 7; d++) {
                const date = new Date(startDay)
                date.setDate(date.getDate() + w * 7 + d)
                const y = date.getFullYear()
                const m = date.getMonth() + 1
                const day = date.getDate()
                const key = _key(y, m, day)
                const inMonth = (m === displayMonth)

                let label = ""
                if (_holidays[key]) label = _holidays[key]
                else if (_workdays[key]) label = _workdays[key]
                else if (_festivals[key]) label = _festivals[key][0]

                _daysModel.append({
                    year: y, month: m, day: day,
                    weekday: date.getDay(),
                    inMonth: inMonth,
                    label: label,
                    isHoliday: !!_holidays[key],
                    isWorkday: !!_workdays[key],
                    isToday: key === todayKey
                })
            }
        }
    }
}
