.pragma library

// 农历换算。日历 JSON 里只有节假日/调休/节日三张表，没有逐日农历，
// 结果就是每个格子只有一个数字可放。这里补上「初几」。
//
// 开销：纯计算，无 IO 无对象分配到堆外。只在换月填面板时跑，一次 42 格 ×
// 3 个面板，单次是几十次整数运算，不进入渲染循环。
//
// 数据表覆盖 2010–2049。表本身是农历界通用的位压缩格式：
//   bit 16      闰月是大月(30)还是小月(29)
//   bit 15..4   一到十二月各自大小月，1 为大月
//   bit 3..0    闰月月份，0 表示当年无闰月
// 校验：2015–2030 十六年春节日期全部吻合，且与 asset/calendar/2026.json
// 里 8 个农历节日（腊八/春节/元宵/端午/七夕/中元/中秋/重阳）逐一对上。
var LUNAR_INFO = [
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0
]

var BASE_YEAR = 2010
// 2010 年正月初一，全部换算的起点
var BASE_DATE = Date.UTC(2010, 1, 14)

var MONTH_NAMES = ["正", "二", "三", "四", "五", "六",
                   "七", "八", "九", "十", "冬", "腊"]
var DAY_TENS = ["初", "十", "廿", "卅"]
var DAY_UNITS = ["十", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

function _info(y) {
    var i = y - BASE_YEAR
    return (i < 0 || i >= LUNAR_INFO.length) ? 0 : LUNAR_INFO[i]
}

function _leapMonth(y) {
    return _info(y) & 0xf
}

function _leapDays(y) {
    if (!_leapMonth(y))
        return 0
    return (_info(y) & 0x10000) ? 30 : 29
}

function _monthDays(y, m) {
    return (_info(y) & (0x10000 >> m)) ? 30 : 29
}

function _yearDays(y) {
    var sum = 348
    for (var i = 0x8000; i > 0x8; i >>= 1) {
        if (_info(y) & i)
            sum += 1
    }
    return sum + _leapDays(y)
}

// 公历 → 农历。返回 { year, month, day, isLeap }，超出表范围返回 null
function fromSolar(year, month, day) {
    if (year < BASE_YEAR || year > BASE_YEAR + LUNAR_INFO.length - 1)
        return null

    var offset = Math.floor((Date.UTC(year, month - 1, day) - BASE_DATE) / 86400000)
    if (offset < 0)
        return null

    var y = BASE_YEAR
    while (y < BASE_YEAR + LUNAR_INFO.length) {
        var yd = _yearDays(y)
        if (offset < yd)
            break
        offset -= yd
        y += 1
    }
    if (y >= BASE_YEAR + LUNAR_INFO.length)
        return null

    var leap = _leapMonth(y)
    var isLeap = false
    var temp = 0
    var m = 1
    while (m < 13 && offset > 0) {
        // 闰月排在同名月之后，命中时把月号退回去再走一遍
        if (leap > 0 && m === leap + 1 && !isLeap) {
            m -= 1
            isLeap = true
            temp = _leapDays(y)
        } else {
            temp = _monthDays(y, m)
        }
        if (isLeap && m === leap + 1)
            isLeap = false
        offset -= temp
        m += 1
    }
    if (offset === 0 && leap > 0 && m === leap + 1) {
        if (isLeap)
            isLeap = false
        else {
            isLeap = true
            m -= 1
        }
    }
    if (offset < 0) {
        offset += temp
        m -= 1
    }

    return { year: y, month: m, day: offset + 1, isLeap: isLeap }
}

function dayName(d) {
    if (d === 10) return "初十"
    if (d === 20) return "二十"
    if (d === 30) return "三十"
    return DAY_TENS[Math.floor(d / 10)] + DAY_UNITS[d % 10]
}

function monthName(m, isLeap) {
    var n = MONTH_NAMES[m - 1] || ""
    return (isLeap ? "闰" : "") + n + "月"
}

// 格子里那一行小字：每月初一显示月名，其余显示初几
function cellText(year, month, day) {
    var l = fromSolar(year, month, day)
    if (!l)
        return ""
    return l.day === 1 ? monthName(l.month, l.isLeap) : dayName(l.day)
}

// 完整农历日期，给「今天」那一条用
function fullText(year, month, day) {
    var l = fromSolar(year, month, day)
    if (!l)
        return ""
    return monthName(l.month, l.isLeap) + dayName(l.day)
}
