// WeatherForecast — 天气页预报区：小时曲线（Canvas）与七日列表，两者交叉淡入淡出
//
// 小时有底卡；七日取消套层，直接铺在岛底色上。
// 第 10 轮从 WeatherPage 摘出来——这一区连 Canvas 的 onPaint 一起 355 行，
// 是原文件里最大的一坨。重绘的触发源（数据变、尺寸变、主题换色、切段）
// 现在全在本文件里，不用再回页根找 repaintHourly() 是谁在调。
//
// 跟页面的接口：
//   page      —— 回引页根，取色标和七日温差范围（见 WeatherPage 文件头）
//   hourly    —— 显示小时还是七日
//   shown     —— 错峰入场

import QtQuick
import QtQuick.Layouts
import qs.data.state
import qs.data.service

Rectangle {
    id: forecast

    property Item page: null
    property bool hourly: true
    property bool shown: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: hourly ? Size.rounding.lg : 0
    color: hourly ? Color.surfaceContainerHigh : "transparent"
    clip: true

    opacity: shown ? 1 : 0
    transform: Translate {
        y: forecast.shown ? 0 : 16
        Behavior on y { Anim { type: Anim.Enter } }
    }
    Behavior on opacity { Anim { type: Anim.EffectsSlow } }
    Behavior on color { CAnim {} }

    function repaintHourly() {
        if (hourlyCanvas.available)
            hourlyCanvas.requestPaint()
    }

    // 切回小时段时补一次：淡出期间的数据变更没有重绘（Canvas 不可见）
    onHourlyChanged: if (hourly) repaintHourly()

    Connections {
        target: Weather
        function onHourlyChanged() { forecast.repaintHourly() }
        function onReadyChanged() { forecast.repaintHourly() }
    }

    Item {
        anchors.fill: parent
        anchors.margins: forecast.hourly ? Size.spacing.md : Size.spacing.sm

        Canvas {
            id: hourlyCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            opacity: forecast.hourly ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { Anim { type: Anim.Effects } }

            Connections {
                target: Color
                function onPrimaryChanged() { forecast.repaintHourly() }
            }

            Component.onCompleted: Qt.callLater(forecast.repaintHourly)
            onWidthChanged: forecast.repaintHourly()
            onHeightChanged: forecast.repaintHourly()

            onPaint: {
                const data = Weather.hourly
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (!data || data.length === 0) {
                    ctx.fillStyle = Color.textMuted
                    ctx.font = "14px '" + Size.fontSans + "'"
                    ctx.textAlign = "center"
                    ctx.fillText("暂无小时预报", width / 2, height / 2)
                    return
                }

                let minTemp = 999, maxTemp = -999
                for (let i = 0; i < data.length; i++) {
                    const t = data[i].temp
                    if (t < minTemp) minTemp = t
                    if (t > maxTemp) maxTemp = t
                }
                if (maxTemp - minTemp < 4) {
                    const mid = (maxTemp + minTemp) / 2
                    maxTemp = mid + 2
                    minTemp = mid - 2
                }
                // 无条件留余量。此前只在温差 < 4 时补，于是 18–23° 这种
                // 刚好不触发的量程会把最低温那条线压在画布最底边：
                // 平段贴底、上半片全空，到降水带的虚线也被压成零长度。
                const headroom = (maxTemp - minTemp) * 0.18
                maxTemp += headroom
                minTemp -= headroom

                const padTop = 28, padBottom = 28, padSide = 36
                const timeY = height - 4
                // 底部让出一条降水带；温度曲线相应上移
                const precipH = 26
                const precipBottom = height - padBottom + 2
                const precipTop = precipBottom - precipH
                // 概率数字单独占一行：96% 的柱子几乎填满泳道，
                // 数字压在柱子上会被盖掉
                const popLabelY = precipTop - 4
                const guideBottom = popLabelY - 10
                const drawHeight = Math.max(1, guideBottom - padTop)
                const drawWidth = Math.max(1, width - padSide * 2)
                const stepX = data.length > 1 ? drawWidth / (data.length - 1) : 0
                const points = []

                for (let j = 0; j < data.length; j++) {
                    const normalized = (data[j].temp - minTemp) / (maxTemp - minTemp)
                    points.push({
                        x: padSide + j * stepX,
                        y: padTop + (1 - normalized) * drawHeight,
                        data: data[j]
                    })
                }

                // ---- 昼夜底色 ----
                // 只给夜间段压一层暗色，白天不画。这样无论配色怎么变，
                // 「暗的是夜里」都成立；若两边都上色则依赖冷暖对比，换主题就失效。
                // 到 precipTop 为止：底下那条降水带必须保持统一底色，
                // 否则同样概率的柱子压在夜色上和白天上会呈现两种深浅。
                ctx.save()
                ctx.fillStyle = Color.withAlpha(Color.background, 0.38)
                for (let n = 0; n < points.length; n++) {
                    if (points[n].data.day)
                        continue
                    const half = stepX / 2
                    let x0 = points[n].x - half
                    let x1 = points[n].x + half
                    // 首尾段补到画布边缘，免得留两条突兀的白边
                    if (n === 0) x0 = 0
                    if (n === points.length - 1) x1 = width
                    ctx.fillRect(x0, 0, x1 - x0, precipTop)
                }
                ctx.restore()

                // ---- 昼夜分界 ----
                // 光有深浅两块底色，看到的人只会问「为什么一半深一半浅」。
                // 在交界处画线并标出日出 / 日落，那块底色才成为信息。
                ctx.save()
                ctx.strokeStyle = Color.withAlpha(Color.textMuted, 0.55)
                ctx.lineWidth = 1
                ctx.setLineDash([3, 3])
                ctx.textAlign = "center"
                for (let m = 1; m < points.length; m++) {
                    if (points[m].data.day === points[m - 1].data.day)
                        continue
                    const bx = Math.round((points[m - 1].x + points[m].x) / 2) + 0.5
                    ctx.beginPath()
                    ctx.moveTo(bx, 13)
                    ctx.lineTo(bx, precipTop)
                    ctx.stroke()
                    ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.95)
                    ctx.font = "10px '" + Size.fontSans + "'"
                    ctx.fillText(points[m].data.day ? "日出" : "日落", bx, 10)
                }
                ctx.restore()

                // ---- 降水柱 ----
                // 柱高 = 降水概率，柱色深浅 = 雨量。
                // 只有图标的话，「30% 飘点雨」和「96% 下大雨」长得一模一样。
                ctx.save()
                // 独立底槽：让降水带自成一条泳道，柱子才不会被读成背景色块
                ctx.fillStyle = Color.withAlpha(Color.background, 0.55)
                ctx.fillRect(0, precipTop, width, precipH)

                const barW = Math.max(3, Math.min(14, stepX * 0.46))
                for (let b = 0; b < points.length; b++) {
                    const pop = Number(points[b].data.pop) || 0
                    if (pop <= 0)
                        continue
                    const mm = Number(points[b].data.mm) || 0
                    const h = Math.max(2, (pop / 100) * precipH)
                    // 1mm 以上就按最深画，再大在这个尺度上看不出差别
                    const alpha = 0.45 + Math.min(1, mm) * 0.55
                    ctx.fillStyle = Color.withAlpha(Color.secondary, alpha)
                    ctx.fillRect(points[b].x - barW / 2, precipBottom - h, barW, h)
                }
                // 泳道标签。没有它，这排柱子就是一排看不懂的方块
                ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.75)
                ctx.font = "10px '" + Size.fontSans + "'"
                ctx.textAlign = "left"
                ctx.fillText("降水", 2, precipBottom - 8)

                // 概率数字。柱高已经编码了概率，但「看着挺高」答不了
                // 「到底是 66% 还是 96%」——要不要带伞是靠后者决定的
                ctx.fillStyle = Color.withAlpha(Color.textMuted, 0.9)
                ctx.font = "10px '" + Size.fontMono + "'"
                ctx.textAlign = "center"
                for (let q = 0; q < points.length; q++) {
                    const pq = Number(points[q].data.pop) || 0
                    if (pq <= 0)
                        continue
                    ctx.fillText(pq + "%", points[q].x, popLabelY)
                }

                // 降水带基线，给柱子一个落脚点
                ctx.strokeStyle = Color.withAlpha(Color.outlineVariant, 0.5)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(0, precipBottom + 0.5)
                ctx.lineTo(width, precipBottom + 0.5)
                ctx.stroke()
                ctx.restore()

                // 节点 → 降水带 垂直虚线（同一 paint，无额外 Item）
                ctx.save()
                ctx.strokeStyle = Color.withAlpha(Color.textMuted, 0.45)
                ctx.lineWidth = 1.25
                ctx.setLineDash([4, 5])
                for (let g = 0; g < points.length; g++) {
                    const gp = points[g]
                    ctx.beginPath()
                    ctx.moveTo(gp.x, gp.y + 6)
                    ctx.lineTo(gp.x, guideBottom)
                    ctx.stroke()
                }
                ctx.restore()

                // ---- 温度曲线 ----
                // 按高度上色标：低处冷色、高处暖色，与 UV / PM2.5 那两条
                // 刻度条同一套配色。于是「哪段热」不必去读数字。
                // 一次 createLinearGradient，不额外分配纹理。
                const tempGrad = ctx.createLinearGradient(0, padTop, 0, guideBottom)
                const rs = forecast.page ? forecast.page.rampStops : []
                for (let s = 0; s < rs.length; s++)
                    tempGrad.addColorStop(s / (rs.length - 1), rs[rs.length - 1 - s])

                ctx.beginPath()
                ctx.moveTo(points[0].x, points[0].y)
                for (let k = 1; k < points.length; k++)
                    ctx.lineTo(points[k].x, points[k].y)
                ctx.lineWidth = 2.5
                ctx.strokeStyle = tempGrad
                ctx.stroke()

                for (let p = 0; p < points.length; p++) {
                    const pt = points[p]
                    // 节点取自己那档温度的颜色，和曲线上的位置对得上
                    const dotColor = forecast.page
                        ? forecast.page.rampColor(
                            (pt.data.temp - minTemp) / (maxTemp - minTemp))
                        : Color.primary
                    ctx.beginPath()
                    ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2)
                    ctx.fillStyle = Color.surfaceContainerHigh
                    ctx.fill()
                    ctx.lineWidth = 2
                    ctx.strokeStyle = dotColor
                    ctx.stroke()

                    // 首尾点改对齐，避免温度/时刻贴边被裁
                    if (p === 0)
                        ctx.textAlign = "left"
                    else if (p === points.length - 1)
                        ctx.textAlign = "right"
                    else
                        ctx.textAlign = "center"

                    ctx.fillStyle = Color.backgroundText
                    ctx.font = "bold 13px '" + Size.fontMono + "'"
                    ctx.fillText(pt.data.temp + "°", pt.x, pt.y - 14)

                    ctx.fillStyle = Color.textMuted
                    ctx.font = "12px '" + Size.fontSans + "'"
                    ctx.fillText(pt.data.time, pt.x, timeY)
                }
            }
        }

        // 7 日：用 Column 均分高度（不靠 Layout.fillHeight，那个在这里会收成 0）
        Column {
            id: dailyCol
            anchors.fill: parent
            opacity: forecast.hourly ? 0.0 : 1.0
            visible: opacity > 0.01
            Behavior on opacity { Anim { type: Anim.Effects } }

            readonly property int rowH: Math.max(
                36,
                Math.floor(height / Math.max(1, Weather.daily.length))
            )

            Repeater {
                model: Weather.daily

                Item {
                    required property var modelData
                    required property int index
                    width: dailyCol.width
                    height: dailyCol.rowH

                    RowLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Size.spacing.md
                        height: 34

                        Text {
                            Layout.preferredWidth: 58
                            text: modelData.day
                            color: index === 0 ? Color.primary : Color.textMuted
                            font.family: Size.fontSans
                            font.pixelSize: Size.fontSize.bodyMedium
                            font.bold: index === 0
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        WeatherIcon {
                            sourceUrl: modelData.icon
                            pixelSize: 30
                            contentScale: 1.2
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.preferredWidth: 38
                            text: modelData.minTemp
                            color: Color.textMuted
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.bodyMedium
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 3
                                radius: 1.5
                                color: Color.withAlpha(Color.textMuted, 0.2)
                            }
                            // 条的左右端各取自己那档温度的颜色。位置说的是
                            // 「这天在这周里偏冷还是偏热」，颜色把同一件事再说一遍，
                            // 于是扫一眼就能分出「凉到热」和「一直热」。
                            Rectangle {
                                id: tempBar
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property real span: forecast.page
                                    ? forecast.page.dailyTempSpan : 1
                                readonly property real base: forecast.page
                                    ? forecast.page.dailyMinC : 0
                                readonly property real loR: ((Number(modelData.minC) || 0) - base) / span
                                readonly property real hiR: ((Number(modelData.maxC) || 0) - base) / span
                                x: parent.width * loR
                                width: Math.max(12, parent.width * Math.max(0.08, hiR - loR))
                                height: 7
                                radius: 3.5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop {
                                        position: 0
                                        color: forecast.page
                                            ? forecast.page.rampColor(tempBar.loR) : Color.primary
                                    }
                                    GradientStop {
                                        position: 1
                                        color: forecast.page
                                            ? forecast.page.rampColor(tempBar.hiR) : Color.error
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: 38
                            text: modelData.maxTemp
                            color: Color.text
                            font.family: Size.fontMono
                            font.pixelSize: Size.fontSize.titleSmall
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        visible: index < (Weather.daily.length - 1)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Color.withAlpha(Color.textMuted, 0.1)
                    }
                }
            }
        }
    }
}
