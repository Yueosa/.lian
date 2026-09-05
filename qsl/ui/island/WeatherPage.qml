// WeatherPage — Hub 天气（去天穹，MetricTile 紧凑布局）
// 数据：Weather 服务；定位：点地名搜索
// 性能：随 Hub Loader 销毁；无 Astro/skyCanvas；hourly Canvas 仅数据/尺寸变更时重绘
// 布局：ColumnLayout 分区，避免锚点互相顶、顶行被裁
//
// 第 10 轮拆分（原 1233 行，一个 ColumnLayout 独吃 801 行）：
//   WeatherNow       上排：地名/刷新 + 主视觉 + 今日温标 + 六个格
//   WeatherNowcast   分段开关 + 降水临近预报
//   WeatherForecast  预报区：小时 Canvas + 七日列表
//   WeatherSearch    定位搜索浮层
//   WeatherMetricTile / WeatherGaugeTile   原来的两个内联 component
//
// 本文件只剩编排，外加四个区**跨区共用**的东西——它们留在这儿是因为不属于任何
// 单独一区：`isHourly` 由分段条改、预报区读；色标和七日温差范围被上排的今日温标
// 和预报区的七日条同时读。子件通过 `page` 回引取用，不各自复制一份。

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root
    anchors.fill: parent

    property bool isHourly: true

    // 7 日温差条全局范围（随 daily 变；无额外对象常驻）
    readonly property real dailyMinC: {
        const d = Weather.daily
        if (!d || d.length === 0)
            return 0
        let lo = 999
        for (let i = 0; i < d.length; i++)
            lo = Math.min(lo, Number(d[i].minC) || 0)
        return lo
    }
    readonly property real dailyMaxC: {
        const d = Weather.daily
        if (!d || d.length === 0)
            return 1
        let hi = -999
        for (let i = 0; i < d.length; i++)
            hi = Math.max(hi, Number(d[i].maxC) || 0)
        return hi
    }
    readonly property real dailyTempSpan: Math.max(1, dailyMaxC - dailyMinC)

    // 冷 → 热的四段色标。与 UV / PM2.5 刻度条共用同一套，
    // 于是「颜色越靠后 = 程度越强」在整页里是同一条规则。
    readonly property var rampStops: [Color.primary, Color.secondary, Color.tertiary, Color.error]

    // 取色标上任意位置的颜色。纯算术，不建对象、不开缓冲；
    // 调用点是 7 日条（14 次/刷新）和 Canvas 渐变（1 次/重绘），量可以忽略。
    function rampColor(t) {
        const s = root.rampStops
        const n = s.length - 1
        const x = Math.max(0, Math.min(1, Number(t) || 0)) * n
        const i = Math.min(n - 1, Math.floor(x))
        const f = x - i
        const a = s[i], b = s[i + 1]
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1)
    }

    Component.onCompleted: Weather.setDetailActive(true)
    Component.onDestruction: Weather.setDetailActive(false)

    QslStagger { id: stagger }
    function playEnter() { stagger.restart() }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: Size.spacing.lg
        spacing: Size.spacing.sm

        WeatherNow {
            page: root
            shown: stagger.shown(0)
            onSearchRequested: search.toggle()
        }

        WeatherNowcast {
            hourly: root.isHourly
            shown: stagger.shown(1)
            onPick: (wantHourly) => root.isHourly = wantHourly
        }

        WeatherForecast {
            page: root
            hourly: root.isHourly
            shown: stagger.shown(2)
        }
    }

    WeatherSearch {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: Size.spacing.lg + 36
        anchors.leftMargin: Size.spacing.lg
    }
}
