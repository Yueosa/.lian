import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.config
import qs.Widget.common
import Clavis.Weather 1.0

Item {
    id: root

    Theme { id: theme }
    property real cardScale: 1.0

    property int contentMargin: 16
    property int headerHeight: 70
    property bool lightHeaderPalette: currentIsNight()
    property color headerInk: lightHeaderPalette ? Qt.rgba(0.96, 0.98, 1.0, 0.94) : Qt.rgba(0.09, 0.14, 0.20, 0.88)
    property color headerInkMuted: lightHeaderPalette ? Qt.rgba(0.87, 0.91, 0.98, 0.76) : Qt.rgba(0.20, 0.28, 0.38, 0.62)
    property color headerErrorInk: lightHeaderPalette ? Qt.rgba(1.0, 0.79, 0.82, 0.96) : Qt.rgba(0.62, 0.14, 0.18, 0.88)
    property real currentEpoch: Math.floor(Date.now() / 1000)

    property bool locationEditorOpen: false
    property bool geocodeBusy: false
    property string geocodeCity: ""
    property string geocodeCountry: ""
    property string geocodeError: ""
    property var geocodeResults: []
    property var recentCities: []  // [{label, latitude, longitude}]

    function openLocationEditor() {
        geocodeError = ""
        geocodeResults = []
        geocodeCity = ""
        geocodeCountry = ""
        locationEditorOpen = true
    }

    function startGeocodeSearch() {
        if (geocodeBusy) return
        if ((geocodeCity || "").trim().length === 0) {
            geocodeError = "请输入城市名称"
            return
        }
        geocodeError = ""
        geocodeResults = []
        geocodeProc.command = [
            "python3",
            Quickshell.shellDir + "/scripts/weather_geocode.py",
            geocodeCity,
            geocodeCountry
        ]
        geocodeProc.running = true
    }

    Process {
        id: geocodeProc
        running: false
        command: ["python3", Quickshell.shellDir + "/scripts/weather_geocode.py", "", ""]

        onRunningChanged: root.geocodeBusy = running

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse((data || "").trim())
                    root.geocodeResults = Array.isArray(parsed) ? parsed : []
                    if (root.geocodeResults.length === 0)
                        root.geocodeError = "未找到匹配城市，请尝试更具体的城市/国家"
                } catch (e) {
                    root.geocodeResults = []
                    root.geocodeError = "位置查询失败，请稍后再试"
                }
            }
        }
    }

    function validNumber(value) {
        return value !== undefined && value !== null && !isNaN(value)
    }

    function fmtTemp(value) {
        return validNumber(value) ? Math.round(value) + "°" : "--"
    }

    function fmtTempPlain(value) {
        return validNumber(value) ? Math.round(value).toString() : "--"
    }

    function fmtTime(epoch) {
        if (!epoch) return "--"
        return Qt.formatDateTime(new Date(epoch * 1000), "hh:mm")
    }

    function fmtSpeed(ms) {
        return validNumber(ms) ? ms.toFixed(1) + " m/s" : "--"
    }

    function fmtPercent(value) {
        return validNumber(value) ? Math.round(value) + "%" : "--"
    }

    function fmtDistance(meters) {
        return validNumber(meters) ? (meters / 1000).toFixed(1) + " km" : "--"
    }

    function currentHour() {
        return new Date(root.currentEpoch * 1000).getHours()
    }

    function updatedText() {
        if (WeatherPlugin.loading) return "正在刷新"
        if (WeatherPlugin.status === "fresh" || WeatherPlugin.status === "partial") {
            const date = new Date(WeatherPlugin.lastUpdated)
            return "更新于 " + Qt.formatDateTime(date, "hh:mm")
        }
        if (WeatherPlugin.status === "stale") return "数据较旧"
        if (WeatherPlugin.status === "error") return "更新失败"
        return "待更新"
    }

    function dayLabel(index, epoch) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        return epoch ? Qt.formatDateTime(new Date(epoch * 1000), "ddd") : "--"
    }

    function uvLevel(value) {
        if (!validNumber(value)) return "--"
        if (value < 3) return "低"
        if (value < 6) return "中"
        if (value < 8) return "高"
        if (value < 11) return "很高"
        return "极高"
    }

    function uvIndexBucket(value) {
        if (!validNumber(value)) return -1
        if (value < 3) return 0
        if (value < 6) return 1
        if (value < 8) return 2
        if (value < 11) return 3
        return 4
    }

    function windAccent(ms) {
        if (!validNumber(ms)) return "#4d8d7b"
        if (ms < 4) return "#72d572"
        if (ms < 6) return "#ffca28"
        if (ms < 8) return "#ffa726"
        if (ms < 10) return "#e52f35"
        if (ms < 12) return "#99004c"
        return "#7e0023"
    }

    function directionLabel(degree) {
        if (!validNumber(degree)) return "--"
        const normalized = ((degree % 360) + 360) % 360
        if (normalized < 22.5 || normalized >= 337.5) return "N"
        if (normalized < 67.5) return "NE"
        if (normalized < 112.5) return "E"
        if (normalized < 157.5) return "SE"
        if (normalized < 202.5) return "S"
        if (normalized < 247.5) return "SW"
        if (normalized < 292.5) return "W"
        return "NW"
    }

    function activeHalfDay() {
        const day = today()
        const hour = currentHour()
        if (hour < 5) return day.night || ({})
        if (hour < 17) return day.day || ({})
        return day.night || ({})
    }

    function precipitationValueText() {
        const half = activeHalfDay()
        const snow = validNumber(half.snowCm) ? half.snowCm : 0
        const rain = validNumber(half.rainMm) ? half.rainMm : 0
        const total = validNumber(half.precipitationMm) ? half.precipitationMm : NaN
        if (snow > 0 && rain <= 0) return snow.toFixed(1) + " cm"
        return validNumber(total) ? total.toFixed(1) + " mm" : "--"
    }

    function precipitationDescriptionText() {
        const half = activeHalfDay()
        const snow = validNumber(half.snowCm) ? half.snowCm : 0
        const rain = validNumber(half.rainMm) ? half.rainMm : 0
        const hour = currentHour()
        const isDay = hour >= 5 && hour < 17
        if (snow > 0 && rain <= 0) return isDay ? "白天降雪总量" : "夜间降雪总量"
        if (rain > 0 && snow <= 0) return isDay ? "白天降雨总量" : "夜间降雨总量"
        if (snow > 0 && rain > 0) return isDay ? "白天总降水" : "夜间总降水"
        return isDay ? "白天总降水" : "夜间总降水"
    }

    function humidityWaveAccent() {
        return "#625985"
    }

    function visibilityDescription(meters) {
        if (!validNumber(meters)) return "--"
        const km = meters / 1000
        if (km >= 16) return "Crystal clear"
        if (km >= 10) return "Clear"
        if (km >= 6) return "Good"
        if (km >= 3) return "Hazy"
        if (km >= 1) return "Low"
        return "Dense"
    }

    function aqiThresholds() {
        return [0, 20, 50, 100, 150, 250]
    }

    function pollutantIndex(value, thresholds) {
        if (!validNumber(value)) return NaN
        let level = -1
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i]) level = i
        }
        if (level < 0) return NaN
        const aqi = aqiThresholds()
        if (level < thresholds.length - 1) {
            const bpLo = thresholds[level]
            const bpHi = thresholds[level + 1]
            const inLo = aqi[level]
            const inHi = aqi[level + 1]
            return Math.round(((inHi - inLo) / (bpHi - bpLo)) * (value - bpLo) + inLo)
        }
        return Math.round((value * aqi[aqi.length - 1]) / thresholds[thresholds.length - 1])
    }

    function aqiLevelIndex(value) {
        if (!validNumber(value)) return -1
        const thresholds = aqiThresholds()
        let level = 0
        for (let i = 0; i < thresholds.length; ++i) {
            if (value >= thresholds[i]) level = i
        }
        return Math.min(level, 5)
    }

    function aqiPalette(level) {
        const colors = ["#00e59b", "#ffc302", "#ff712b", "#f62a55", "#c72eaa", "#9930ff"]
        return colors[Math.max(0, Math.min(colors.length - 1, level))]
    }

    function aqiLevelName(level) {
        const names = ["优", "良", "差", "不健康", "很不健康", "危险"]
        if (level < 0 || level >= names.length) return "--"
        return names[level]
    }

    function aqiSummary() {
        const air = WeatherPlugin.currentAirQuality || ({})
        const values = [
            pollutantIndex(air.ozone, [0, 50, 100, 160, 240, 480]),
            pollutantIndex(air.nitrogenDioxide, [0, 10, 25, 200, 400, 1000]),
            pollutantIndex(air.pm10, [0, 15, 45, 80, 160, 400]),
            pollutantIndex(air.pm25, [0, 5, 15, 30, 60, 150])
        ].filter(validNumber)
        if (values.length === 0) return ({ value: NaN, level: "--", color: "#00e59b" })
        const value = Math.max.apply(Math, values)
        const level = aqiLevelIndex(value)
        return ({ value: value, level: aqiLevelName(level), color: aqiPalette(level) })
    }

    function pressureValueText(value) {
        return validNumber(value) ? Number(value).toLocaleString(Qt.locale(), "f", 1) : "--"
    }

    function today() {
        return WeatherPlugin.dailyForecast.count() > 0 ? WeatherPlugin.dailyForecast.get(0) : ({})
    }

    function currentIsNight() {
        const day = today()
        const sunrise = day.sunrise || 0
        const sunset = day.sunset || 0
        if (sunrise > 0 && sunset > 0) {
            const now = Math.floor(root.currentEpoch)
            return now < sunrise || now >= sunset
        }

        const current = WeatherPlugin.current()
        if (current && current.isDaylight !== undefined) return !current.isDaylight

        const nextHour = WeatherPlugin.hourlyForecast.count() > 0 ? WeatherPlugin.hourlyForecast.get(0) : ({})
        if (nextHour && nextHour.isDaylight !== undefined) return !nextHour.isDaylight

        const name = (WeatherPlugin.currentIconName || "").toLowerCase()
        if (name.indexOf("night") >= 0 || name.indexOf("_night") >= 0) return true
        if (name.indexOf("day") >= 0 || name.indexOf("_day") >= 0) return false

        return false
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.currentEpoch = Math.floor(Date.now() / 1000)
    }

    Rectangle {
        id: weatherPanel
        anchors.fill: parent
        radius: Sizes.rounding.pill
        clip: true
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Colorscheme.outline_variant.r, Colorscheme.outline_variant.g, Colorscheme.outline_variant.b, 0.34)
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: weatherPanel.width
                height: weatherPanel.height
                radius: weatherPanel.radius
            }
        }

        WeatherBackground {
            anchors.fill: parent
            weatherCode: WeatherPlugin.currentWeatherCode
            iconName: WeatherPlugin.currentIconName
            windSpeedMs: WeatherPlugin.currentWindSpeedMs
            windGustsMs: WeatherPlugin.currentWindGustsMs
            night: root.currentIsNight()
            rainBounceY: flick.y + dailyForecastCard.y - flick.contentY
            scrollProgress: Math.max(0, Math.min(1, flick.contentY / 340))
            animate: root.visible
        }

        Rectangle {
            id: fixedHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.headerHeight + root.contentMargin
            color: "transparent"
            border.width: 0

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: root.contentMargin
                anchors.topMargin: root.contentMargin
                height: root.headerHeight
                spacing: Sizes.spacing.xsm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.md

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.splus

                        Text {
                            text: "location_on"
                            color: root.headerInkMuted
                            font.family: Sizes.fontIcon
                            font.pixelSize: Sizes.font.hero
                            Layout.preferredWidth: 20
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: WeatherPlugin.locationName || "Weather"
                            color: root.headerInk
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.hero
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ToolButton {
                        id: editButton
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: root.openLocationEditor()

                        background: Rectangle {
                            radius: width / 2
                            color: editButton.down
                                   ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                                   : editButton.hovered
                                     ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.10)
                                     : "transparent"
                        }

                        contentItem: Text {
                            text: "edit"
                            color: root.headerInk
                            font.family: Sizes.fontIcon
                            font.pixelSize: Sizes.font.h1
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ToolButton {
                        id: refreshButton
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter
                        enabled: !WeatherPlugin.loading
                        opacity: enabled ? 1 : 0.45
                        onClicked: WeatherPlugin.refresh()

                        background: Rectangle {
                            radius: width / 2
                            color: refreshButton.down
                                   ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.18)
                                   : refreshButton.hovered
                                     ? Qt.rgba(root.headerInkMuted.r, root.headerInkMuted.g, root.headerInkMuted.b, 0.10)
                                     : "transparent"
                        }

                        contentItem: Text {
                            text: "refresh"
                            color: root.headerInk
                            font.family: Sizes.fontIcon
                            font.pixelSize: Sizes.font.h1
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.splus
                    Layout.topMargin: 2

                    Text {
                        text: "schedule"
                        color: WeatherPlugin.status === "stale" || WeatherPlugin.status === "error"
                               ? root.headerErrorInk
                               : root.headerInkMuted
                        font.family: Sizes.fontIcon
                        font.pixelSize: Sizes.font.hero
                        Layout.preferredWidth: 20
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: updatedText()
                        color: WeatherPlugin.status === "stale" || WeatherPlugin.status === "error"
                               ? root.headerErrorInk
                               : root.headerInk
                        font.family: Sizes.fontFamilyMono
                        font.pixelSize: Sizes.font.sm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.bottomMargin: 2
                    }
                }
            }
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fixedHeader.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.contentMargin
            anchors.rightMargin: root.contentMargin
            anchors.bottomMargin: root.contentMargin
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 4

            Column {
                id: contentColumn
                width: flick.width
                spacing: Sizes.spacing.l

                Item {
                    width: parent.width
                    height: Math.max(220, flick.height - 452 - 286 - contentColumn.spacing * 2)

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Sizes.spacing.sm

                        Text {
                            width: parent.width
                            text: WeatherPlugin.currentWeatherText || "Unknown"
                            color: Colorscheme.on_surface
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.h2b
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Item {
                            id: currentVisual
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tempText.implicitWidth + weatherHeroIcon.width - 18
                            height: Math.max(tempText.implicitHeight, weatherHeroIcon.height + 12)

                            Text {
                                id: tempText
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                text: fmtTempPlain(WeatherPlugin.currentTemperatureC)
                                color: Colorscheme.on_surface
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.jumbo
                                font.bold: true
                                font.letterSpacing: 0
                            }

                            MeteoIcon {
                                id: weatherHeroIcon
                                width: 108
                                height: 108
                                anchors.right: parent.right
                                anchors.top: parent.top
                                weatherCode: WeatherPlugin.currentWeatherCode
                                iconName: WeatherPlugin.currentIconName
                                night: root.currentIsNight()
                            }
                        }

                        Text {
                            width: parent.width
                            text: "体感温度: " + fmtTemp(WeatherPlugin.currentFeelsLikeC)
                            color: Colorscheme.on_surface
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.xxl
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: "最高 " + fmtTemp(today().temperatureMaxC)
                                  + " · 最低 " + fmtTemp(today().temperatureMinC)
                            color: Colorscheme.on_surface
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.xxl
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    width: 1
                    height: 14
                }

                DailyForecastTrendCard {
                    id: dailyForecastCard
                    width: parent.width
                    height: Math.round(452 * root.cardScale)
                    sourceModel: WeatherPlugin.dailyTrendForecast
                }

                HourlyForecastTrendCard {
                    width: parent.width
                    height: Math.round(286 * root.cardScale)
                    sourceModel: WeatherPlugin.hourlyForecast
                }

                RowLayout {
                    width: parent.width
                    spacing: Sizes.spacing.m

                    WeatherPrecipitationCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        valueText: precipitationValueText()
                        descriptionText: precipitationDescriptionText()
                    }

                    WeatherWindCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        directionDegrees: WeatherPlugin.currentWindDirection
                        valueText: fmtSpeed(WeatherPlugin.currentWindSpeedMs)
                        detailText: "阵风 " + fmtSpeed(WeatherPlugin.currentWindGustsMs) + " · " + directionLabel(WeatherPlugin.currentWindDirection)
                        accent: windAccent(WeatherPlugin.currentWindSpeedMs)
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Sizes.spacing.m

                    WeatherAqiCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        aqiValue: aqiSummary().value
                        levelText: aqiSummary().level
                        accent: aqiSummary().color
                    }

                    WeatherPollenCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        pollenMap: today().pollen || ({})
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Sizes.spacing.m

                    WeatherHumidityCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        humidityValue: WeatherPlugin.currentRelativeHumidity
                        humidityText: fmtPercent(WeatherPlugin.currentRelativeHumidity)
                        dewPointText: fmtTemp(WeatherPlugin.currentDewPointC)
                        accent: humidityWaveAccent()
                    }

                    WeatherUvCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        value: WeatherPlugin.currentUvIndex
                        level: uvLevel(WeatherPlugin.currentUvIndex)
                        activeIndex: uvIndexBucket(WeatherPlugin.currentUvIndex)
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Sizes.spacing.m

                    WeatherVisibilityCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        visibilityMeters: WeatherPlugin.currentVisibilityM
                    }

                    WeatherPressureCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        pressureValue: WeatherPlugin.currentPressureHpa
                        valueText: pressureValueText(WeatherPlugin.currentPressureHpa)
                        unitText: "hPa"
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Sizes.spacing.m

                    WeatherAstroCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        moon: false
                        riseText: fmtTime(today().sunrise)
                        setText: fmtTime(today().sunset)
                        riseEpoch: today().sunrise || 0
                        setEpoch: today().sunset || 0
                        currentEpoch: root.currentEpoch
                    }

                    WeatherAstroCard {
                        Layout.preferredWidth: (parent.width - parent.spacing) / 2
                        Layout.preferredHeight: Layout.preferredWidth
                        moon: true
                        riseText: fmtTime(today().moonrise)
                        setText: fmtTime(today().moonset)
                        riseEpoch: today().moonrise || 0
                        setEpoch: today().moonset || 0
                        currentEpoch: root.currentEpoch
                        phaseAngle: today().moonPhaseAngle || 0
                    }
                }

                Item {
                    width: 1
                    height: 8
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.locationEditorOpen
        z: 1000

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.locationEditorOpen = false
        }

        Rectangle {
            width: Math.min(parent.width - 32, 420)
            height: Math.min(parent.height - 32, 460)
            anchors.centerIn: parent
            radius: Sizes.rounding.card
            color: Colorscheme.surface_container_high
            border.width: 1
            border.color: Qt.rgba(Colorscheme.outline_variant.r, Colorscheme.outline_variant.g, Colorscheme.outline_variant.b, 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: Sizes.spacing.m

                Text {
                    text: "设置天气位置"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.xxl
                    font.bold: true
                    color: Colorscheme.on_surface
                }

                Text {
                    text: "国家/城市通过联网查询，选择结果后立即切换。"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface_variant
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                WeatherFormField {
                    id: cityInput
                    Layout.fillWidth: true
                    placeholderText: "城市（必填），例如 Tokyo"
                    text: root.geocodeCity
                    onTextChanged: root.geocodeCity = text
                    onAccepted: root.startGeocodeSearch()
                }

                WeatherFormField {
                    Layout.fillWidth: true
                    placeholderText: "国家（可选），例如 Japan"
                    text: root.geocodeCountry
                    onTextChanged: root.geocodeCountry = text
                    onAccepted: root.startGeocodeSearch()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.sm

                    WeatherActionButton {
                        text: "自动定位"
                        onClicked: {
                            WeatherPlugin.clearManualLocation()
                            root.locationEditorOpen = false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    WeatherActionButton {
                        text: "查询"
                        enabled: !root.geocodeBusy
                        filled: true
                        onClicked: root.startGeocodeSearch()
                    }

                    WeatherActionButton {
                        text: "关闭"
                        onClicked: root.locationEditorOpen = false
                    }
                }

                Text {
                    visible: root.geocodeBusy
                    text: "正在查询..."
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.primary
                }

                Text {
                    visible: root.geocodeError.length > 0
                    text: root.geocodeError
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.error
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Sizes.spacing.s
                    model: root.geocodeResults

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 56
                        radius: Sizes.rounding.medium
                        color: rowMouse.containsMouse
                               ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.14)
                               : Qt.rgba(Colorscheme.surface_container_low.r, Colorscheme.surface_container_low.g, Colorscheme.surface_container_low.b, 0.8)

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: Sizes.spacing.xxs

                            Text {
                                text: modelData.label || ""
                                color: Colorscheme.on_surface
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.md
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "lat " + Number(modelData.latitude).toFixed(3) + " · lon " + Number(modelData.longitude).toFixed(3)
                                color: Colorscheme.on_surface_variant
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.xsm
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                const label = modelData.label || modelData.name || "Manual location"
                                const lat = Number(modelData.latitude)
                                const lon = Number(modelData.longitude)
                                WeatherPlugin.setManualLocation(lat, lon, label)
                                let cities = root.recentCities.filter(c => c.label !== label)
                                cities.unshift({label: label, latitude: lat, longitude: lon})
                                root.recentCities = cities.slice(0, 5)
                                root.locationEditorOpen = false
                            }
                        }
                    }
                }

                // 最近使用城市 chips
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.s
                    visible: root.recentCities.length > 0

                    Text {
                        text: "最近使用"
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.sm
                        color: Colorscheme.on_surface_variant
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s

                        Repeater {
                            model: root.recentCities

                            delegate: Rectangle {
                                required property var modelData

                                height: 28
                                width: chipLabel.implicitWidth + 24
                                radius: Sizes.rounding.chip
                                color: chipMouse.containsMouse
                                       ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.18)
                                       : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.35)

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData.label || ""
                                    font.family: Sizes.fontFamily
                                    font.pixelSize: Sizes.font.sm
                                    color: Colorscheme.primary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        WeatherPlugin.setManualLocation(
                                            Number(modelData.latitude),
                                            Number(modelData.longitude),
                                            modelData.label || "Manual location"
                                        )
                                        root.locationEditorOpen = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component WeatherFormField: TextField {
        id: fieldRoot

        Material.theme: Material.System
        Material.accent: Colorscheme.primary
        Material.primary: Colorscheme.primary
        Material.background: Colorscheme.surface
        Material.foreground: Colorscheme.on_surface
        Material.containerStyle: Material.Outlined

        implicitHeight: 52
        property bool blinkOn: true
        renderType: Text.QtRendering
        selectedTextColor: Colorscheme.on_secondary_container
        selectionColor: Colorscheme.secondary_container
        placeholderTextColor: Colorscheme.outline
        clip: true
        selectByMouse: true
        wrapMode: TextEdit.NoWrap

        font {
            pixelSize: 14
            hintingPreference: Font.PreferFullHinting
            family: Sizes.fontFamily
        }

        cursorDelegate: Rectangle {
            width: 2
            radius: Sizes.rounding.hairline
            color: Colorscheme.primary
            visible: fieldRoot.activeFocus && fieldRoot.blinkOn
        }

        onActiveFocusChanged: {
            fieldRoot.blinkOn = true
            if (activeFocus)
                cursorBlinkTimer.restart()
            else
                cursorBlinkTimer.stop()
        }

        Timer {
            id: cursorBlinkTimer
            interval: 530
            repeat: true
            running: fieldRoot.activeFocus
            onTriggered: fieldRoot.blinkOn = !fieldRoot.blinkOn
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
        }
    }

    component WeatherActionButton: Rectangle {
        id: actionButton

        property alias text: label.text
        property bool filled: false
        signal clicked()

        implicitWidth: label.implicitWidth + 28
        implicitHeight: 34
        radius: height / 2
        opacity: enabled ? 1 : 0.55
        color: filled
            ? (buttonMouse.pressed ? Colorscheme.primary_container
               : buttonMouse.containsMouse ? Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.85)
               : Qt.rgba(Colorscheme.primary_container.r, Colorscheme.primary_container.g, Colorscheme.primary_container.b, 0.7))
            : (buttonMouse.pressed ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.20)
               : buttonMouse.containsMouse ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12)
               : "transparent")

        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            id: label
            anchors.centerIn: parent
            font.pixelSize: Sizes.font.sm
            font.bold: true
            color: Colorscheme.primary
            font.family: Sizes.fontFamily

            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: actionButton.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    component SectionCard: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias content: contentLayer.data

        radius: Sizes.rounding.xxxl
        color: Qt.rgba(Colorscheme.surface_container.r, Colorscheme.surface_container.g, Colorscheme.surface_container.b, 0.78)
        border.width: 1
        border.color: Qt.rgba(Colorscheme.outline_variant.r, Colorscheme.outline_variant.g, Colorscheme.outline_variant.b, 0.55)

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 18
            anchors.topMargin: 16
            spacing: Sizes.spacing.sm

            Text {
                text: card.icon
                color: Colorscheme.on_surface
                font.family: Sizes.fontIcon
                font.pixelSize: Sizes.font.title
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: card.title
                color: Colorscheme.on_surface
                font.family: Sizes.fontFamily
                font.bold: true
                font.pixelSize: Sizes.font.body
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item {
            id: contentLayer
            anchors.fill: parent
            anchors.margins: 14
        }
    }

}
