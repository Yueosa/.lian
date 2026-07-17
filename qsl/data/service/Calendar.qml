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
//   days           model    当月日期列表（兼容其它消费者）
//
// 方法：
//   setMonth(year, month, rebuildDays=true)
//   buildDays(year, month)  → 42 格数组（Overview 轮转用）
//   shiftMonth(y, m, delta) → { year, month }
//   previousMonth / nextMonth / resetToToday
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
                root._allDates = Object.keys(Object.assign({}, h, w, f)).sort()

                resetToToday()
            } catch (e) {}
        }
    }

    function _resolveDataPath() {
        const year = new Date().getFullYear()
        const base = String(Qt.resolvedUrl("../../asset/calendar/"))
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
    function shiftMonth(year, month, delta) {
        let y = Number(year) || 0
        let m = Number(month) || 1
        let d = Number(delta) || 0
        m += d
        while (m > 12) { m -= 12; y += 1 }
        while (m < 1) { m += 12; y -= 1 }
        return { year: y, month: m }
    }

    // 纯函数：任意月 42 格，供 Overview 预缓存相邻月
    function buildDays(year, month) {
        const y0 = Number(year) || 0
        const m0 = Number(month) || 1
        if (y0 <= 0 || m0 < 1 || m0 > 12)
            return []

        const today = new Date()
        const todayKey = _key(today.getFullYear(), today.getMonth() + 1, today.getDate())
        const first = new Date(y0, m0 - 1, 1)
        const startDay = new Date(first)
        startDay.setDate(startDay.getDate() - first.getDay())

        const out = []
        for (let w = 0; w < 6; w++) {
            for (let d = 0; d < 7; d++) {
                const date = new Date(startDay)
                date.setDate(date.getDate() + w * 7 + d)
                const y = date.getFullYear()
                const m = date.getMonth() + 1
                const day = date.getDate()
                const key = _key(y, m, day)
                const inMonth = (m === m0)
                let label = ""
                if (_holidays[key]) label = _holidays[key]
                else if (_workdays[key]) label = _workdays[key]
                else if (_festivals[key]) label = _festivals[key][0]
                const weekday = date.getDay()
                out.push({
                    year: y, month: m, day: day,
                    weekday: weekday,
                    inMonth: inMonth,
                    label: label,
                    isHoliday: !!_holidays[key],
                    isWorkday: !!_workdays[key],
                    isToday: key === todayKey,
                    isWeekend: weekday === 0 || weekday === 6
                })
            }
        }
        return out
    }

    // rebuildDays=false：只改显示年月（Overview 轮转每步调用，避免白刷 ListModel）
    function setMonth(year, month, rebuildDays) {
        displayYear = year
        displayMonth = month
        if (rebuildDays !== false)
            _rebuild()
    }

    function previousMonth() {
        const p = shiftMonth(displayYear, displayMonth, -1)
        setMonth(p.year, p.month)
    }

    function nextMonth() {
        const p = shiftMonth(displayYear, displayMonth, 1)
        setMonth(p.year, p.month)
    }

    function resetToToday() {
        const now = new Date()
        setMonth(now.getFullYear(), now.getMonth() + 1)
    }

    function _rebuild() {
        _daysModel.clear()
        const built = buildDays(displayYear, displayMonth)
        for (let i = 0; i < built.length; i++)
            _daysModel.append(built[i])
    }
}
