pragma Singleton

-- ============================================================
-- 时钟服务 — Time
-- ============================================================
-- 提供秒级基础时间数据。不做衍生计算，业务逻辑留给 UI 层。
-- 所有属性只在值变化时才通知下游（QML 自动跳过同值通知）。
-- ============================================================
-- 对外接口一览：
--
-- 属性（readonly，每秒更新一次）：
--   day      string   日           "2"
--   month    string   月英文缩写  "Jul"
--   hours    string   时（12h）    "03"
--   minutes  string   分           "16"
--   seconds  string   秒           "42"
--   rawDate  date     原始 JS Date 对象，供自定义格式化或计算
-- ============================================================

import Quickshell
import QtQuick

Singleton {
    id: root

    -- 格式化后的日期/时间字符串，UI 可直接显示
    readonly property string day: Qt.formatDateTime(clock.date, "d")       -- 日："2"
    readonly property string month: Qt.formatDateTime(clock.date, "MMM")   -- 月英文缩写："Jul"
    readonly property string hours: Qt.formatDateTime(clock.date, "hh")    -- 时（12h）："03"
    readonly property string minutes: Qt.formatDateTime(clock.date, "mm")  -- 分："16"
    readonly property string seconds: Qt.formatDateTime(clock.date, "ss")  -- 秒："42"

    -- 原始 JS Date 对象，供需要自定义格式化或计算的 UI 使用
    readonly property date rawDate: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Seconds  -- 秒级精度，每秒更新一次
    }
}
