import QtQuick
import QtQuick.Controls
import qs.config
import "../../JS/weather.js" as WeatherJS

Rectangle {
    id: root

    property var sourceModel
    property int maxDays: 6
    property var items: []
    property var keyLines: []
    property real chartMax: 150
    property bool hasData: false

    readonly property real sidePadding: 18
    readonly property real topPadding: 16
    readonly property real chartTop: 90
    readonly property real chartBottom: height - 56
    readonly property real chartWidth: Math.max(0, width - sidePadding * 2)
    readonly property real columnWidth: items.length > 0 ? chartWidth / items.length : chartWidth

    radius: Sizes.rounding.card
    color: Qt.rgba(Colorscheme.surface_container_high.r, Colorscheme.surface_container_high.g, Colorscheme.surface_container_high.b, 0.42)
    clip: true

    function dailyAqiValue(air) {
        if (!air) return NaN
        const values = [
            WeatherJS.pollutantIndex(air.ozone, [0, 50, 100, 160, 240, 480]),
            WeatherJS.pollutantIndex(air.nitrogenDioxide, [0, 10, 25, 200, 400, 1000]),
            WeatherJS.pollutantIndex(air.pm10, [0, 15, 45, 80, 160, 400]),
            WeatherJS.pollutantIndex(air.pm25, [0, 5, 15, 30, 60, 150])
        ].filter(function(v) { return !isNaN(v) })
        if (values.length === 0) return NaN
        return Math.max.apply(Math, values)
    }

    function dayLabel(index, epoch) {
        if (index === 0) return "昨天"
        if (index === 1) return "今天"
        if (index === 2) return "明天"
        if (!epoch) return "--"
        const week = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return week[new Date(epoch * 1000).getDay()]
    }

    function dateLabel(epoch) {
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "M/d") : "--"
    }

    function yForValue(value) {
        if (value === undefined || value === null || isNaN(value)) return chartBottom
        if (chartMax <= 0) return chartBottom
        const clamped = Math.max(0, Math.min(chartMax, value))
        return chartBottom - clamped / chartMax * (chartBottom - chartTop)
    }

    function chartUpperBound(highest) {
        if (highest === undefined || highest === null || isNaN(highest) || highest <= 0) return 100
        if (highest <= 100) return 100
        if (highest <= 150) return 150
        if (highest <= 250) return 250
        return Math.ceil(highest / 50) * 50
    }

    function rebuild() {
        const list = []
        let highest = 0
        let validCount = 0
        const count = sourceModel && sourceModel.count ? Math.min(maxDays, sourceModel.count()) : 0
        for (let i = 0; i < count; ++i) {
            const day = sourceModel.get(i) || ({})
            const aqi = dailyAqiValue(day.airQuality || ({}))
            const level = WeatherJS.aqiLevelIndex(aqi)
            if (!isNaN(aqi)) {
                highest = Math.max(highest, aqi)
                validCount += 1
            }
            list.push({
                time: day.time || 0,
                dayText: dayLabel(i, day.time || 0),
                dateText: dateLabel(day.time || 0),
                aqi: aqi,
                aqiText: !isNaN(aqi) ? Math.round(aqi).toString() : "--",
                levelText: WeatherJS.aqiLevelName(level),
                color: WeatherJS.aqiPalette(level),
                emphasized: i !== 0
            })
        }
        items = list
        chartMax = chartUpperBound(highest)
        hasData = validCount > 0

        const lines = [
            { value: 20, label: WeatherJS.aqiLevelName(1) },
            { value: 100, label: WeatherJS.aqiLevelName(3) }
        ]
        if (chartMax >= 250) {
            lines.push({ value: 250, label: WeatherJS.aqiLevelName(5) })
        }
        keyLines = lines
    }

    onSourceModelChanged: rebuild()
    onWidthChanged: rebuild()
    onHeightChanged: rebuild()
    Component.onCompleted: rebuild()

    Connections {
        target: root.sourceModel
        ignoreUnknownSignals: true

        function onModelReset() {
            root.rebuild()
        }

        function onRowsInserted() {
            root.rebuild()
        }

        function onRowsRemoved() {
            root.rebuild()
        }

        function onDataChanged() {
            root.rebuild()
        }
    }

    Repeater {
        model: root.keyLines

        Item {
            required property var modelData

            x: root.sidePadding
            y: root.yForValue(modelData.value)
            width: root.chartWidth
            height: 20

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.rgba(Colorscheme.outline_variant.r, Colorscheme.outline_variant.g, Colorscheme.outline_variant.b, 0.44)
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.verticalCenter
                anchors.leftMargin: 2
                anchors.bottomMargin: 5
                text: modelData.value
                color: Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.72)
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.xsm
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.verticalCenter
                anchors.rightMargin: 2
                anchors.bottomMargin: 5
                text: modelData.label
                color: Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.72)
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.sm
            }
        }
    }

    Repeater {
        model: root.items

        Item {
            required property var modelData
            required property int index

            x: root.sidePadding + index * root.columnWidth
            y: 0
            width: root.columnWidth
            height: root.height

            readonly property real barWidth: Math.max(14, Math.min(22, width * 0.26))
            readonly property real barHeight: !isNaN(modelData.aqi) ? Math.max(10, root.chartBottom - root.yForValue(modelData.aqi)) : 0
            readonly property color weekColor: modelData.emphasized
                                               ? Colorscheme.on_surface
                                               : Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.78)
            readonly property color dateColor: modelData.emphasized
                                               ? Colorscheme.on_surface_variant
                                               : Qt.rgba(Colorscheme.on_surface_variant.r, Colorscheme.on_surface_variant.g, Colorscheme.on_surface_variant.b, 0.62)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.topPadding
                text: modelData.dayText
                color: parent.weekColor
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.lg
                font.bold: modelData.dayText === "今天"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.topPadding + 22
                text: modelData.dateText
                color: parent.dateColor
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.xsm
            }

            Rectangle {
                visible: !isNaN(modelData.aqi)
                width: parent.barWidth
                height: parent.barHeight
                x: (parent.width - width) / 2
                y: root.chartBottom - height
                radius: width / 2
                color: Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.58)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.chartBottom + 10
                text: modelData.aqiText
                color: Colorscheme.on_surface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.md
                font.bold: modelData.dayText === "今天"
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasData
        text: "空气质量数据暂不可用"
        color: Colorscheme.on_surface_variant
        font.family: Sizes.fontFamily
        font.pixelSize: Sizes.font.xl
    }
}
