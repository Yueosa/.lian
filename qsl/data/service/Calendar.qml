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

//
// 方法：
//   setMonth(year, month)
//   buildDays(year, month)  → 42 格数组（Overview 轮转用）
//   shiftMonth(y, m, delta) → { year, month }

// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import "lunar.js" as Lunar

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
    property var _holidayRanges: []  // [{ name, start, end }]，按年份顺序

    // 今天的农历，例：六月二十
    readonly property string todayLunar: {
        void sourceTitle
        const t = new Date()
        return Lunar.fullText(t.getFullYear(), t.getMonth() + 1, t.getDate())
    }

    // 下一个法定假期。已经放在假里就返回剩余天数（daysAway <= 0）。
    // 依赖 _holidayRanges，随 sourceTitle 一并就位后重算一次，之后静止。
    readonly property var nextHoliday: {
        const rs = root._holidayRanges || []
        if (rs.length === 0)
            return null
        const now = new Date()
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        let best = null
        for (let i = 0; i < rs.length; i++) {
            const e = new Date(rs[i].end)
            if (e < today)
                continue
            const s = new Date(rs[i].start)
            const days = Math.round((s - today) / 86400000)
            if (best === null || days < best.daysAway)
                best = { name: rs[i].name, daysAway: days, start: rs[i].start }
        }
        return best
    }

    function _key(y, m, d) { return y + "-" + String(m).padStart(2,'0') + "-" + String(d).padStart(2,'0') }

    // ---- 加载 JSON 数据 ----
    FileView {
        id: _dataFile
        path: _resolveDataPath()

        onLoaded: {
            try {
                const json = JSON.parse(_dataFile.text());
                const h = {}, w = {}, f = {}
                const ranges = []
                for (const item of json.holidays || []) {
                    _fillRange(h, item.start, item.end, item.name)
                    ranges.push({ name: item.name, start: item.start, end: item.end })
                }
                root._holidayRanges = ranges
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


                // sourceTitle 是「数据已就位」的对外信号，消费者靠它重建视图。
                // QML 属性赋值同步发信号，所以它必须排在三张表之后——
                // 放在前面的话，订阅方会在表还空着的时候就去 buildDays，
                // 拿到一个没有节日的月份，而且此后再没有东西会触发重建。
                sourceTitle = json.sourceTitle || ""
                sourceUrl = json.sourceUrl || ""

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
                    // 没有节日的日子退回农历初几，格子才不会只剩一个数字
                    lunar: Lunar.cellText(y, m, day),
                    isHoliday: !!_holidays[key],
                    isWorkday: !!_workdays[key],
                    isToday: key === todayKey,
                    isWeekend: weekday === 0 || weekday === 6
                })
            }
        }
        return out
    }

    // 只改显示年月。这里原先还带一个 rebuildDays 参数，用来顺带刷一个对外的
    // days ListModel——而那个模型全树无人读（Overview 直接调 buildDays 自己拼），
    // 唯一的真实调用点又都传 false。整套跟着删了，参数也就没了。
    function setMonth(year, month) {
        displayYear = year
        displayMonth = month
    }

    // 数据装载完把显示月归到当月。是本文件内部调用（_dataFile.onLoaded），
    // 全树搜 `Calendar.resetToToday` 搜不到它——同文件内的无限定调用是死代码
    // 盘点的盲区，这条差点被当成没人用删掉
    function resetToToday() {
        const now = new Date()
        setMonth(now.getFullYear(), now.getMonth() + 1)
    }
}
