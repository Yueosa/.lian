import QtQuick
import qs.config
import "../../../JS/weather.js" as WeatherJS
import "../../../JS/astro.js" as AstroJS
import Clavis.Weather 1.0

Item {
    id: root
    width: 720
    height: 540
    
    
    property real latitude: WeatherPlugin.latitude
    property real longitude: WeatherPlugin.longitude
    property string locationName: WeatherPlugin.locationName || "LOCATING..."

    property string currentTemp: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentTemperatureC) + "°" : "--"
    property string currentIcon: WeatherPlugin.hasValidData ? WeatherJS.getFontAwesomeIcon(WeatherPlugin.currentWeatherCode) : ""
    property string currentDesc: WeatherPlugin.currentWeatherText || "--"
    property string feelsLike: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentFeelsLikeC) + "°C" : "--"
    property string humidity: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentRelativeHumidity) + "%" : "--"
    property string windSpeed: WeatherPlugin.hasValidData ? (WeatherPlugin.currentWindSpeedMs * 3.6).toFixed(1) + " km/h" : "--"
    property string pressure: WeatherPlugin.hasValidData ? Math.round(WeatherPlugin.currentPressureHpa) + " hPa" : "--"
    
    property bool isHourly: true
    property var hourlyData: []
    property var dailyData: []
    property real sunAzimuth: 0
    property real sunAltitude: 0

    Component.onCompleted: {
        if (WeatherPlugin.hasValidData) rebuildForecastData()
        updateAstroData()
    }

    // ================== 全局 UI 超时控制 ==================
    Timer {
        id: forceStopTimer
        interval: 5000
        onTriggered: root.stopRefreshAnim()
    }

    function stopRefreshAnim() {
        forceStopTimer.stop()
        if (spinAnim.running) spinAnim.stop()
        resetAnim.start()
    }

    // 监听 WeatherPlugin 数据变化
    Connections {
        target: WeatherPlugin
        function onDataChanged() {
            if (WeatherPlugin.hasValidData) {
                rebuildForecastData()
                updateAstroData()
            }
            root.stopRefreshAnim()
        }
        function onLoadingChanged() {
            if (!WeatherPlugin.loading) root.stopRefreshAnim()
        }
    }

    function rebuildForecastData() {
        // 小时预报：取接下来 12 条
        var tempHourly = []
        var hModel = WeatherPlugin.hourlyForecast
        var nowTs = Math.floor(Date.now() / 1000)
        var startIdx = 0
        for (var i = 0; i < hModel.count(); i++) {
            var item = hModel.get(i)
            if ((item.time || 0) >= nowTs) { startIdx = i; break }
        }
        for (var h = 0; h < 12 && (startIdx + h) < hModel.count(); h++) {
            var row = hModel.get(startIdx + h)
            var t = new Date((row.time || 0) * 1000)
            tempHourly.push({
                time: t.getHours().toString().padStart(2, '0') + ":00",
                temp: Math.round(row.temperatureC || 0),
                icon: WeatherJS.getFontAwesomeIcon(row.weatherCode || 0)
            })
        }
        root.hourlyData = tempHourly

        // 日预报：取 7 天
        var tempDaily = []
        var dModel = WeatherPlugin.dailyForecast
        var dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        for (var d = 0; d < 7 && d < dModel.count(); d++) {
            var drow = dModel.get(d)
            var dateObj = new Date((drow.time || 0) * 1000)
            tempDaily.push({
                day: (d === 0) ? "Today" : dayNames[dateObj.getDay()],
                icon: WeatherJS.getFontAwesomeIcon(drow.weatherCode || 0),
                maxTemp: Math.round(drow.temperatureMaxC || 0) + "°",
                minTemp: Math.round(drow.temperatureMinC || 0) + "°"
            })
        }
        root.dailyData = tempDaily

        hourlyCanvas.requestPaint()
    }

    function updateAstroData() {
        if(root.latitude === 0 && root.longitude === 0) return;
        var pos = AstroJS.getSunPosition(new Date(), root.latitude, root.longitude);
        root.sunAzimuth = pos.az;
        root.sunAltitude = pos.alt;
        skyCanvas.requestPaint();
    }

    Timer { interval: 60000; running: root.visible; repeat: true; onTriggered: updateAstroData() }

    // ==========================================
    // 布局设计
    // ==========================================
    
    // 1. 左上：综合天气信息
    Item {
        id: infoSection
        width: 220
        height: 220
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 25
        
        Column {
            spacing: Sizes.spacing.sm
            
            Row {
                spacing: Sizes.spacing.sm
                Text {
                    text: root.locationName 
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.body; font.bold: true; font.letterSpacing: 2
                    color: Colorscheme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                // 刷新按钮组件
                Rectangle {
                    width: 24
                    height: 24
                    radius: Sizes.rounding.normal
                    color: refreshMouseArea.pressed ? Colorscheme.surface_variant : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: ""
                        font.family: Sizes.fontAwesome
                        font.pixelSize: Sizes.font.xl
                        color: refreshMouseArea.containsMouse ? Colorscheme.primary : Colorscheme.on_surface_variant
                        
                        // 1. 无限循环的转圈动画
                        NumberAnimation {
                            id: spinAnim
                            target: refreshIcon
                            property: "rotation"
                            from: 0; to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }

                        // 2. 抄近道顺滑归位动画 (利用 RotationAnimation.Shortest 算法)
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
                        id: refreshMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!spinAnim.running) {
                                resetAnim.stop()
                                refreshIcon.rotation = 0
                                spinAnim.start()
                                forceStopTimer.restart()
                                WeatherPlugin.refresh()
                            }
                        }
                    }
                }
            }
            
            Row {
                spacing: Sizes.spacing.md
                Text { 
                    text: root.currentIcon; font.family: Sizes.fontAwesome; 
                    font.pixelSize: Sizes.font.h7; color: Colorscheme.primary 
                }
                Text { 
                    text: root.currentTemp; font.family: Sizes.fontFamilyMono; 
                    font.pixelSize: Sizes.font.h7; font.bold: true; color: Colorscheme.on_surface 
                }
            }
            Text { text: root.currentDesc; font.family: Sizes.fontFamily; font.pixelSize: Sizes.font.xxl; font.bold: true; color: Colorscheme.on_surface }
            
            Item { height: 10; width: 1 } 
            
            Grid {
                columns: 2
                spacing: Sizes.spacing.md
                columnSpacing: 24
                
                Row { spacing: Sizes.spacing.s; Text { text: ""; font.family: Sizes.fontAwesome; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.body } Text { text: root.feelsLike; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md } }
                Row { spacing: Sizes.spacing.s; Text { text: ""; font.family: Sizes.fontAwesome; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.body } Text { text: root.humidity; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md } }
                Row { spacing: Sizes.spacing.s; Text { text: ""; font.family: Sizes.fontAwesome; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.body } Text { text: root.windSpeed; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md } }
                Row { spacing: Sizes.spacing.s; Text { text: ""; font.family: Sizes.fontAwesome; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.body } Text { text: root.pressure; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md } }
            }
        }
    }

    // 2. 左侧下方：完美的 Material 3 分段形变按钮
    Item {
        id: segmentedContainer
        width: 200
        height: 40
        anchors.top: infoSection.bottom
        anchors.left: parent.left
        anchors.margins: 25

        Row {
            anchors.fill: parent
            spacing: Sizes.spacing.xs 

            // 12 Hrs 按键
            Rectangle {
                width: (parent.width - 4) / 2; height: parent.height
                color: root.isHourly ? Colorscheme.primary : Colorscheme.surface_variant
                
                topLeftRadius: 20; bottomLeftRadius: 20
                topRightRadius: root.isHourly ? 20 : 6
                bottomRightRadius: root.isHourly ? 20 : 6
                
                Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Sizes.spacing.xs
                    Text { text: ""; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.lg; color: Colorscheme.on_primary; visible: root.isHourly }
                    Text { text: "12 Hrs"; font.family: Sizes.fontFamily; font.bold: true; font.pixelSize: Sizes.font.md; color: root.isHourly ? Colorscheme.on_primary : Colorscheme.on_surface_variant }
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = true }
            }

            // 7 Days 按键
            Rectangle {
                width: (parent.width - 4) / 2; height: parent.height
                color: !root.isHourly ? Colorscheme.primary : Colorscheme.surface_variant
                
                topRightRadius: 20; bottomRightRadius: 20
                topLeftRadius: !root.isHourly ? 20 : 6
                bottomLeftRadius: !root.isHourly ? 20 : 6
                
                Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: Sizes.spacing.xs
                    Text { text: ""; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.lg; color: Colorscheme.on_primary; visible: !root.isHourly }
                    Text { text: "7 Days"; font.family: Sizes.fontFamily; font.bold: true; font.pixelSize: Sizes.font.md; color: !root.isHourly ? Colorscheme.on_primary : Colorscheme.on_surface_variant }
                }
                MouseArea { anchors.fill: parent; onClicked: root.isHourly = false }
            }
        }
    }

    // 3. 右半场：天穹图
    Item {
        id: astroArea
        anchors.top: parent.top
        anchors.bottom: forecastCard.top
        anchors.left: infoSection.right
        anchors.right: parent.right
        anchors.margins: 10
        
        Canvas {
            id: skyCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            // 【新增：监听主题色变化并强制重绘】
            Connections {
                target: Colorscheme
                function onPrimaryChanged() {
                    skyCanvas.requestPaint()
                }
            }

            onPaint: {
                if(root.latitude === 0) return;
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var R = 125; 

                function project(az, alt) {
                    var r = R * (1 - alt / (Math.PI / 2));
                    return {x: cx + r * Math.sin(az), y: cy - r * Math.cos(az)};
                }

                ctx.lineWidth = 1.5;
                ctx.strokeStyle = Colorscheme.outline_variant; 
                
                [0, 30, 60].forEach(function(deg) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, R * (1 - deg / 90), 0, Math.PI * 2);
                    ctx.stroke();
                    if(deg > 0) {
                        ctx.fillStyle = Colorscheme.on_surface_variant;
                        ctx.font = "11px '" + Sizes.fontFamilyMono + "'";
                        ctx.fillText(deg + "°", cx + 4, cy - R * (1 - deg / 90) - 4);
                    }
                });
                
                ctx.beginPath();
                ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R);
                ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy);
                ctx.stroke();

                var y = new Date().getFullYear();
                var terms = [
                    { date: new Date(y, 5, 21), color: "rgba(239, 68, 68, 0.6)" }, 
                    { date: new Date(y, 2, 21), color: "rgba(34, 197, 94, 0.6)" }, 
                    { date: new Date(y, 11, 21), color: "rgba(56, 189, 248, 0.6)" }
                ];
                
                ctx.setLineDash([4, 6]);
                ctx.lineWidth = 1.5;
                for(var j=0; j<terms.length; j++) {
                    ctx.strokeStyle = terms[j].color;
                    ctx.beginPath();
                    var isFirstRef = true;
                    for (var min = 0; min <= 24 * 60; min += 20) {
                        var t = new Date(terms[j].date.getTime() + min * 60000);
                        var pos = AstroJS.getSunPosition(t, root.latitude, root.longitude);
                        if (pos.alt >= 0) {
                            var pt = project(pos.az, pos.alt);
                            if (isFirstRef) { ctx.moveTo(pt.x, pt.y); isFirstRef = false; } 
                            else { ctx.lineTo(pt.x, pt.y); }
                        } else {
                            isFirstRef = true; 
                        }
                    }
                    ctx.stroke();
                }
                ctx.setLineDash([]);

                var startOfDay = new Date(); startOfDay.setHours(0,0,0,0);
                
                

                ctx.beginPath();
                ctx.lineWidth = 2.5;
                ctx.strokeStyle = "#fbbf24"; 
                ctx.setLineDash([6, 6]); 
                var isFirstDay = true;
                for (var md = 0; md <= 24 * 60; md += 10) {
                    var td = new Date(startOfDay.getTime() + md * 60000);
                    var pd = AstroJS.getSunPosition(td, root.latitude, root.longitude);
                    if (pd.alt >= 0) {
                        var pttd = project(pd.az, pd.alt);
                        if (isFirstDay) { ctx.moveTo(pttd.x, pttd.y); isFirstDay = false; } 
                        else { ctx.lineTo(pttd.x, pttd.y); }
                    } else { 
                        isFirstDay = true; 
                    }
                }
                ctx.stroke();
                ctx.setLineDash([]);


                if (root.sunAltitude >= 0) {
                    var currentPt = project(root.sunAzimuth, root.sunAltitude);
                    
                    var glowRadius = 22; 
                    var gradient = ctx.createRadialGradient(currentPt.x, currentPt.y, 4, currentPt.x, currentPt.y, glowRadius);
                    
                    gradient.addColorStop(0, "rgba(253, 224, 71, 0.8)");   
                    gradient.addColorStop(0.4, "rgba(253, 224, 71, 0.3)"); 
                    gradient.addColorStop(1, "rgba(253, 224, 71, 0.0)");   

                    ctx.beginPath(); 
                    ctx.arc(currentPt.x, currentPt.y, glowRadius, 0, Math.PI*2);
                    ctx.fillStyle = gradient; 
                    ctx.fill();
                    
                    ctx.beginPath(); 
                    ctx.arc(currentPt.x, currentPt.y, 5, 0, Math.PI*2);
                    ctx.fillStyle = "#ffffff";
                    ctx.fill();
                } 
                
                ctx.fillStyle = Colorscheme.on_surface;
                ctx.font = "bold 16px '" + Sizes.fontFamilyMono + "'";
                ctx.textAlign = "center"; ctx.textBaseline = "middle";
                ctx.fillText("N", cx, cy - R - 20);
                ctx.fillText("E", cx + R + 22, cy);
                ctx.fillText("S", cx, cy + R + 20);
                ctx.fillText("W", cx - R - 22, cy);
            }
        }
    }

    // 4. 下方：天气预报长卡片
    Rectangle {
        id: forecastCard
        height: 200
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 25
        color: Colorscheme.surface_container
        radius: Sizes.lockCardRadius

        Item {
            anchors.fill: parent
            anchors.margins: 20

            // 12 小时折线图
            Canvas {
                id: hourlyCanvas
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                opacity: root.isHourly ? 1.0 : 0.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }

                // 【新增：监听主题色变化并强制重绘】
                Connections {
                    target: Colorscheme
                    function onPrimaryChanged() {
                        hourlyCanvas.requestPaint()
                    }
                }

                onPaint: {
                    if (!root.hourlyData || root.hourlyData.length === 0) return;
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var minTemp = 999, maxTemp = -999;
                    for (var i = 0; i < root.hourlyData.length; i++) {
                        var t = root.hourlyData[i].temp;
                        if (t < minTemp) minTemp = t;
                        if (t > maxTemp) maxTemp = t;
                    }
                    if (maxTemp - minTemp < 4) { maxTemp += 2; minTemp -= 2; }

                    var points = [];
                    var padTop = 65, padBottom = 20; 
                    var padSide = 35; 
                    var drawHeight = height - padTop - padBottom;
                    var drawWidth = width - padSide * 2;
                    var stepX = drawWidth / (root.hourlyData.length - 1);

                    for (var j = 0; j < root.hourlyData.length; j++) {
                        var normalized = (root.hourlyData[j].temp - minTemp) / (maxTemp - minTemp);
                        points.push({ 
                            x: padSide + j * stepX, 
                            y: padTop + (1 - normalized) * drawHeight, 
                            data: root.hourlyData[j] 
                        });
                    }

                    ctx.beginPath();
                    ctx.moveTo(points[0].x, points[0].y);
                    for (var k = 1; k < points.length; k++) { ctx.lineTo(points[k].x, points[k].y); }
                    ctx.lineWidth = 2.5;
                    ctx.strokeStyle = Colorscheme.primary; 
                    ctx.stroke();

                    ctx.textAlign = "center";
                    for (var p = 0; p < points.length; p++) {
                        var pt = points[p];
                        ctx.beginPath();
                        ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2);
                        ctx.fillStyle = Colorscheme.surface_container; ctx.fill();
                        ctx.lineWidth = 2; ctx.strokeStyle = Colorscheme.primary; ctx.stroke();
                        
                        ctx.fillStyle = Colorscheme.on_surface;
                        ctx.font = "18px '" + Sizes.fontAwesome + "'";
                        ctx.fillText(pt.data.icon, pt.x, pt.y - 22);
                        
                        ctx.font = "bold 13px '" + Sizes.fontFamilyMono + "'";
                        ctx.fillText(pt.data.temp + "°", pt.x, pt.y - 44);
                        
                        ctx.fillStyle = Colorscheme.on_surface_variant;
                        ctx.font = "12px '" + Sizes.fontFamily + "'";
                        ctx.fillText(pt.data.time, pt.x, height - 2);
                    }
                }
            }

            // 7 天排版
            Row {
                anchors.centerIn: parent
                spacing: Sizes.spacing.m
                opacity: root.isHourly ? 0.0 : 1.0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutSine } }

                Repeater {
                    model: root.dailyData
                    Rectangle {
                        width: 82; height: 140; radius: Sizes.rounding.large
                        color: Colorscheme.surface_container_highest
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: Sizes.spacing.md
                            Text { text: modelData.day; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamily; font.pixelSize: Sizes.font.lg; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: modelData.icon; color: Colorscheme.primary; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.h4; anchors.horizontalCenter: parent.horizontalCenter }
                            Column {
                                spacing: Sizes.spacing.xxs; anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: modelData.maxTemp; color: Colorscheme.on_surface; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.xl; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: modelData.minTemp; color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.lg; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
