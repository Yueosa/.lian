// WeatherPage — Island Weather（布局对齐旧 WeatherContent）
// 数据：Weather 服务 / weatherd；定位：点地名搜索
// 性能：随 Hub Loader 销毁；天空穹 60s；无 Lottie

import QtQuick
import qs.data.state
import qs.data.service
import "astro.js" as AstroJS

Item {
    id: root

    readonly property real latitude: Weather.latitude
    readonly property real longitude: Weather.longitude
    readonly property string locationName: Weather.locationName || "定位中…"
    readonly property string currentTemp: Weather.tempText
    readonly property string currentDesc: Weather.weatherText || "--"
    readonly property string feelsLike: Weather.feelsText
    readonly property string humidity: Weather.humidityText
    readonly property string windSpeed: Weather.windText
    readonly property string pressure: Weather.pressureText

    property bool isHourly: true
    property real sunAzimuth: 0
    property real sunAltitude: 0

    function toggleSearch() {
        Weather.searching = !Weather.searching
        if (Weather.searching)
            Qt.callLater(() => searchInput.forceActiveFocus())
        else
            searchInput.text = ""
    }

    function pickLocation(lat, lon, name) {
        Weather.setLocation(lat, lon, name)
        searchInput.text = ""
    }

    Component.onCompleted: {
        Weather.setDetailActive(true)
        updateAstroData()
    }
    Component.onDestruction: Weather.setDetailActive(false)

    Timer {
        id: forceStopTimer
        interval: 5000
        onTriggered: root.stopRefreshAnim()
    }

    function stopRefreshAnim() {
        forceStopTimer.stop()
        if (spinAnim.running)
            spinAnim.stop()
        resetAnim.start()
    }

    Connections {
        target: Weather
        function onLoadingChanged() {
            if (!Weather.loading)
                root.stopRefreshAnim()
        }
        function onReadyChanged() {
            if (Weather.ready)
                root.updateAstroData()
        }
        function onLatitudeChanged() { root.updateAstroData() }
        function onLongitudeChanged() { root.updateAstroData() }
        function onHourlyChanged() {
            hourlyCanvas.requestPaint()
        }
    }

    function updateAstroData() {
        if (root.latitude === 0 && root.longitude === 0)
            return
        const pos = AstroJS.getSunPosition(new Date(), root.latitude, root.longitude)
        root.sunAzimuth = pos.az
        root.sunAltitude = pos.alt
        skyCanvas.requestPaint()
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        onTriggered: root.updateAstroData()
    }

    // ---- 左上信息 ----
    Item {
        id: infoSection
        width: 240
        height: 210
        z: 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        clip: true

        Column {
            width: parent.width
            spacing: Size.spacing.sm

            Row {
                spacing: Size.spacing.sm
                width: parent.width

                Text {
                    id: locLabel
                    text: root.locationName
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.md
                    font.bold: true
                    color: Color.textMuted
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 160)
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSearch()
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: Size.rounding.sm
                    color: refreshMa.pressed ? Color.surfaceHighest : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "\uf021"
                        font.family: Size.fontMono
                        font.pixelSize: Size.fontSize.lg
                        color: refreshMa.containsMouse ? Color.primary : Color.textMuted

                        NumberAnimation {
                            id: spinAnim
                            target: refreshIcon
                            property: "rotation"
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                        RotationAnimation {
                            id: resetAnim
                            target: refreshIcon
                            property: "rotation"
                            to: 0
                            duration: 300
                            direction: RotationAnimation.Shortest
                        }
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!spinAnim.running) {
                                resetAnim.stop()
                                refreshIcon.rotation = 0
                                spinAnim.start()
                                forceStopTimer.restart()
                                Weather.refresh(true)
                            }
                        }
                    }
                }
            }

            Row {
                spacing: Size.spacing.md
                WeatherIcon {
                    sourceUrl: Weather.iconSource
                    pixelSize: 52
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.currentTemp
                    font.family: Size.fontMono
                    font.pixelSize: 48
                    font.bold: true
                    color: Color.textOnBackground
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: root.currentDesc
                font.family: Size.fontSans
                font.pixelSize: Size.fontSize.xl
                font.bold: true
                color: Color.textOnBackground
            }

            Item { height: 8; width: 1 }

            Grid {
                columns: 2
                spacing: Size.spacing.md
                columnSpacing: 20

                Row {
                    spacing: 6
                    Text { text: "\uf2c9"; font.family: Size.fontMono; color: Color.textMuted; font.pixelSize: Size.fontSize.md }
                    Text { text: root.feelsLike; color: Color.textMuted; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm }
                }
                Row {
                    spacing: 6
                    Text { text: "\uf043"; font.family: Size.fontMono; color: Color.textMuted; font.pixelSize: Size.fontSize.md }
                    Text { text: root.humidity; color: Color.textMuted; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm }
                }
                Row {
                    spacing: 6
                    Text { text: "\uf72e"; font.family: Size.fontMono; color: Color.textMuted; font.pixelSize: Size.fontSize.md }
                    Text { text: root.windSpeed; color: Color.textMuted; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm }
                }
                Row {
                    spacing: 6
                    Text { text: "\uf338"; font.family: Size.fontMono; color: Color.textMuted; font.pixelSize: Size.fontSize.md }
                    Text { text: root.pressure; color: Color.textMuted; font.family: Size.fontMono; font.pixelSize: Size.fontSize.sm }
                }
            }
        }
    }

    // 定位搜索浮层：不进 info Column，避免挤矮 12Hrs/7Days
    Rectangle {
        id: searchPanel
        z: 20
        visible: Weather.searching
        width: 260
        // 高度随内容；浮在 info 之上，不改 infoSection 高度
        height: searchCol.implicitHeight + 16
        anchors.top: infoSection.top
        anchors.left: infoSection.left
        anchors.topMargin: 36
        radius: Size.rounding.md
        color: Color.surfaceHigh
        border.color: Color.outlineVariant
        border.width: 1

        Column {
            id: searchCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            Rectangle {
                width: parent.width
                height: 32
                radius: Size.rounding.sm
                color: Color.surfaceHighest

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Color.textOnBackground
                    font.family: Size.fontSans
                    font.pixelSize: Size.fontSize.sm
                    clip: true
                    onTextChanged: geoDebounce.restart()
                    Keys.onReturnPressed: (event) => {
                        Weather.geocode(text)
                        event.accepted = true
                    }
                    Keys.onEscapePressed: (event) => {
                        Weather.searching = false
                        text = ""
                        event.accepted = true
                    }
                }
            }

            Timer {
                id: geoDebounce
                interval: 420
                repeat: false
                onTriggered: {
                    if (searchInput.text.trim().length >= 2)
                        Weather.geocode(searchInput.text)
                }
            }

            Repeater {
                model: Weather.geocodeResults.slice(0, 5)
                Rectangle {
                    required property var modelData
                    width: searchCol.width
                    height: 28
                    radius: Size.rounding.sm
                    color: geoMa.containsMouse ? Color.withAlpha(Color.primary, 0.15) : Color.surfaceHighest

                    Text {
                        anchors.fill: parent
                        anchors.margins: 6
                        text: modelData.label || modelData.name || ""
                        color: Color.textOnBackground
                        font.pixelSize: Size.fontSize.xsm
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: geoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickLocation(modelData.latitude, modelData.longitude,
                            modelData.label || modelData.name || "")
                    }
                }
            }

            Text {
                text: "恢复 IP 定位"
                color: Color.primary
                font.pixelSize: Size.fontSize.xsm
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Weather.resetLocation()
                }
            }
        }
    }

    // ---- 预报卡（先声明，分段/天穹锚其顶） ----
    Rectangle {
        id: forecastCard
        z: 1
        height: 168
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 20
        color: Color.surfaceHigh
        radius: Size.rounding.lg

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Canvas {
                id: hourlyCanvas
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                opacity: root.isHourly ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }

                Connections {
                    target: Color
                    function onPrimaryChanged() { hourlyCanvas.requestPaint() }
                }

                onPaint: {
                    const data = Weather.hourly
                    if (!data || data.length === 0)
                        return
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    let minTemp = 999
                    let maxTemp = -999
                    for (let i = 0; i < data.length; i++) {
                        const t = data[i].temp
                        if (t < minTemp) minTemp = t
                        if (t > maxTemp) maxTemp = t
                    }
                    if (maxTemp - minTemp < 4) {
                        maxTemp += 2
                        minTemp -= 2
                    }

                    const points = []
                    const padTop = 42
                    const padBottom = 18
                    const padSide = 28
                    const drawHeight = height - padTop - padBottom
                    const drawWidth = width - padSide * 2
                    const stepX = data.length > 1 ? drawWidth / (data.length - 1) : 0

                    for (let j = 0; j < data.length; j++) {
                        const normalized = (data[j].temp - minTemp) / (maxTemp - minTemp)
                        points.push({
                            x: padSide + j * stepX,
                            y: padTop + (1 - normalized) * drawHeight,
                            data: data[j]
                        })
                    }

                    ctx.beginPath()
                    ctx.moveTo(points[0].x, points[0].y)
                    for (let k = 1; k < points.length; k++)
                        ctx.lineTo(points[k].x, points[k].y)
                    ctx.lineWidth = 2.5
                    ctx.strokeStyle = Color.primary
                    ctx.stroke()

                    ctx.textAlign = "center"
                    for (let p = 0; p < points.length; p++) {
                        const pt = points[p]
                        ctx.beginPath()
                        ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2)
                        ctx.fillStyle = Color.surfaceHigh
                        ctx.fill()
                        ctx.lineWidth = 2
                        ctx.strokeStyle = Color.primary
                        ctx.stroke()

                        ctx.fillStyle = Color.textOnBackground
                        ctx.font = "bold 13px '" + Size.fontMono + "'"
                        ctx.fillText(pt.data.temp + "°", pt.x, pt.y - 18)

                        ctx.fillStyle = Color.textMuted
                        ctx.font = "12px '" + Size.fontSans + "'"
                        ctx.fillText(pt.data.time, pt.x, height - 2)
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Size.spacing.md
                opacity: root.isHourly ? 0.0 : 1.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }

                Repeater {
                    model: Weather.daily
                    Rectangle {
                        required property var modelData
                        width: 78
                        height: 128
                        radius: Size.rounding.md
                        color: Color.surfaceHighest

                        Column {
                            anchors.centerIn: parent
                            spacing: Size.spacing.sm
                            Text {
                                text: modelData.day
                                color: Color.textMuted
                                font.family: Size.fontSans
                                font.pixelSize: Size.fontSize.md
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            WeatherIcon {
                                sourceUrl: modelData.icon
                                pixelSize: 32
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Column {
                                spacing: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                Text {
                                    text: modelData.maxTemp
                                    color: Color.textOnBackground
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.lg
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: modelData.minTemp
                                    color: Color.textMuted
                                    font.family: Size.fontMono
                                    font.pixelSize: Size.fontSize.md
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- 分段：贴预报卡上方，抬 z 避免被盖 ----
    Item {
        id: segmentedContainer
        width: 200
        height: 36
        z: 3
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.bottom: forecastCard.top
        anchors.bottomMargin: 10

        Row {
            anchors.fill: parent
            spacing: 4

            Rectangle {
                width: (parent.width - 4) / 2
                height: parent.height
                color: root.isHourly ? Color.primary : Color.surfaceHighest
                topLeftRadius: 18
                bottomLeftRadius: 18
                topRightRadius: root.isHourly ? 18 : 6
                bottomRightRadius: root.isHourly ? 18 : 6
                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: "12 Hrs"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.md
                    color: root.isHourly ? Color.textOnPrimary : Color.textMuted
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = true }
            }

            Rectangle {
                width: (parent.width - 4) / 2
                height: parent.height
                color: !root.isHourly ? Color.primary : Color.surfaceHighest
                topRightRadius: 18
                bottomRightRadius: 18
                topLeftRadius: !root.isHourly ? 18 : 6
                bottomLeftRadius: !root.isHourly ? 18 : 6
                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: "7 Days"
                    font.family: Size.fontSans
                    font.bold: true
                    font.pixelSize: Size.fontSize.md
                    color: !root.isHourly ? Color.textOnPrimary : Color.textMuted
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = false }
            }
        }
    }

    // ---- 天穹 ----
    Item {
        id: astroArea
        z: 0
        anchors.top: parent.top
        anchors.bottom: forecastCard.top
        anchors.left: infoSection.right
        anchors.right: parent.right
        anchors.margins: 10
        anchors.bottomMargin: 10

        Canvas {
            id: skyCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            Connections {
                target: Color
                function onPrimaryChanged() { skyCanvas.requestPaint() }
                function onOutlineVariantChanged() { skyCanvas.requestPaint() }
            }

            onPaint: {
                if (root.latitude === 0 && root.longitude === 0)
                    return
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const cx = width / 2
                const cy = height / 2
                const R = Math.min(125, Math.max(60, Math.min(width, height) * 0.38))

                function project(az, alt) {
                    const r = R * (1 - alt / (Math.PI / 2))
                    return { x: cx + r * Math.sin(az), y: cy - r * Math.cos(az) }
                }

                ctx.lineWidth = 1.5
                ctx.strokeStyle = Color.outlineVariant
                ;[0, 30, 60].forEach(function (deg) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, R * (1 - deg / 90), 0, Math.PI * 2)
                    ctx.stroke()
                    if (deg > 0) {
                        ctx.fillStyle = Color.textMuted
                        ctx.font = "11px '" + Size.fontMono + "'"
                        ctx.fillText(deg + "°", cx + 4, cy - R * (1 - deg / 90) - 4)
                    }
                })

                ctx.beginPath()
                ctx.moveTo(cx, cy - R)
                ctx.lineTo(cx, cy + R)
                ctx.moveTo(cx - R, cy)
                ctx.lineTo(cx + R, cy)
                ctx.stroke()

                const startOfDay = new Date()
                startOfDay.setHours(0, 0, 0, 0)
                ctx.beginPath()
                ctx.lineWidth = 2.5
                ctx.strokeStyle = "#fbbf24"
                ctx.setLineDash([6, 6])
                let isFirstDay = true
                for (let md = 0; md <= 24 * 60; md += 15) {
                    const td = new Date(startOfDay.getTime() + md * 60000)
                    const pd = AstroJS.getSunPosition(td, root.latitude, root.longitude)
                    if (pd.alt >= 0) {
                        const pttd = project(pd.az, pd.alt)
                        if (isFirstDay) {
                            ctx.moveTo(pttd.x, pttd.y)
                            isFirstDay = false
                        } else {
                            ctx.lineTo(pttd.x, pttd.y)
                        }
                    } else {
                        isFirstDay = true
                    }
                }
                ctx.stroke()
                ctx.setLineDash([])

                if (root.sunAltitude >= 0) {
                    const currentPt = project(root.sunAzimuth, root.sunAltitude)
                    const glowRadius = 22
                    const gradient = ctx.createRadialGradient(currentPt.x, currentPt.y, 4, currentPt.x, currentPt.y, glowRadius)
                    gradient.addColorStop(0, "rgba(253, 224, 71, 0.8)")
                    gradient.addColorStop(0.4, "rgba(253, 224, 71, 0.3)")
                    gradient.addColorStop(1, "rgba(253, 224, 71, 0.0)")
                    ctx.beginPath()
                    ctx.arc(currentPt.x, currentPt.y, glowRadius, 0, Math.PI * 2)
                    ctx.fillStyle = gradient
                    ctx.fill()
                    ctx.beginPath()
                    ctx.arc(currentPt.x, currentPt.y, 5, 0, Math.PI * 2)
                    ctx.fillStyle = "#ffffff"
                    ctx.fill()
                }

                ctx.fillStyle = Color.textOnBackground
                ctx.font = "bold 16px '" + Size.fontMono + "'"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText("N", cx, cy - R - 20)
                ctx.fillText("E", cx + R + 22, cy)
                ctx.fillText("S", cx, cy + R + 20)
                ctx.fillText("W", cx - R - 22, cy)
            }
        }
    }
}
