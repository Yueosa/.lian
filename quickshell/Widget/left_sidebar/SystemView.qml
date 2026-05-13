import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.Widget.common
import Clavis.Sysmon 1.0
import Quickshell.Io

Item {
    id: root

    // 我们不再依赖 Theme，而是直接全权使用 Colorscheme 热重载注入系统！

    // 格式化工具函数
    function formatBytes(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(1) + " KB/s"
        return bps.toFixed(0) + " B/s"
    }
    function formatMemKB(kb) {
        if (kb >= 1048576) return (kb / 1048576).toFixed(1) + " GB"
        if (kb >= 1024) return (kb / 1024).toFixed(1) + " MB"
        return kb + " KB"
    }

    function formatGiB(value) {
        return Number(value || 0).toFixed(2) + " GiB"
    }

    function pickReadableColor(base, fallback) {
        var bg = Colorscheme.surface_container_lowest
        var c = Qt.color(base)
        var b = Qt.color(bg)
        var l1 = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        var l2 = 0.299 * b.r + 0.587 * b.g + 0.114 * b.b
        if (Math.abs(l1 - l2) < 0.22) return fallback
        return c
    }

    readonly property color netDownColor: pickReadableColor(Colorscheme.primary, Colorscheme.on_surface)
    readonly property color netUpColor: pickReadableColor(Colorscheme.secondary, Colorscheme.on_surface)
    readonly property color ramLineColor: pickReadableColor(Colorscheme.tertiary, Colorscheme.on_surface)
    readonly property color load1Color: pickReadableColor(Colorscheme.error, Colorscheme.on_surface)
    readonly property color load5Color: pickReadableColor(Colorscheme.secondary, Colorscheme.on_surface)
    readonly property color load15Color: pickReadableColor(Colorscheme.primary, Colorscheme.on_surface)

    // 折线图历史数据缓存 (historyLen+1 个采样点，起始全部填 0 避免初期拉伸)
    readonly property int historyLen: 30
    function makeZeroHistory() { var a = []; for (var i = 0; i <= historyLen; ++i) a.push(0); return a }
    property var netDownHistory: makeZeroHistory()
    property var netUpHistory: makeZeroHistory()
    property var ramHistory: makeZeroHistory()
    property var load1History: makeZeroHistory()
    property var load5History: makeZeroHistory()
    property var load15History: makeZeroHistory()
    property int chartRevision: 0

    // 平滑滑动进度 0→1，数据到达时从 0 动画至 1
    property real slideProgress: 0

    // 平滑纵坐标最大值 — 避免瞬间突变
    property real smoothMaxNet: 1024
    property real smoothMaxLoad: 1
    Behavior on smoothMaxNet { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    Behavior on smoothMaxLoad { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onSmoothMaxNetChanged: chartRevision += 1
    onSmoothMaxLoadChanged: chartRevision += 1

    NumberAnimation {
        id: slideAnim
        target: root
        property: "slideProgress"
        from: 0; to: 1
        duration: 1000 // 与 fast timer 间隔一致
    }

    onSlideProgressChanged: chartRevision += 1

    function pushHistory(arr, val) {
        arr.push(val)
        if (arr.length > historyLen + 1) arr.shift()
        return arr
    }

    Connections {
        target: SysmonPlugin
        function onFastDataChanged() {
            // 先重置滑动进度，避免上一轮 prog=1 与新数据错位导致闪一下
            if (root.currentChartTab !== 2) {
                slideAnim.stop()
                root.slideProgress = 0
            }
            root.netDownHistory = pushHistory(root.netDownHistory, SysmonPlugin.netDownBps)
            root.netUpHistory = pushHistory(root.netUpHistory, SysmonPlugin.netUpBps)
            root.ramHistory = pushHistory(root.ramHistory, SysmonPlugin.ramUsage / 100.0)
            root.chartRevision += 1
            // 计算网络纵坐标平滑最大值
            var allNet = root.netDownHistory.concat(root.netUpHistory)
            var rawNetMax = Math.max.apply(null, allNet) * 1.2
            if (rawNetMax <= 0) rawNetMax = 1024
            root.smoothMaxNet = rawNetMax
            // 仅当当前标签页是 Net 或 RAM 时才触发滑动
            if (root.currentChartTab !== 2) {
                slideAnim.duration = 1000  // fast timer 间隔
                slideAnim.start()
            }
        }
        function onMediumDataChanged() {
            if (root.currentChartTab === 2) {
                slideAnim.stop()
                root.slideProgress = 0
            }
            root.load1History = pushHistory(root.load1History, SysmonPlugin.load1)
            root.load5History = pushHistory(root.load5History, SysmonPlugin.load5)
            root.load15History = pushHistory(root.load15History, SysmonPlugin.load15)
            root.chartRevision += 1
            // 计算负载纵坐标平滑最大值
            var allLoad = root.load1History.concat(root.load5History, root.load15History)
            var rawLoadMax = Math.max.apply(null, allLoad) * 1.2
            if (rawLoadMax <= 0) rawLoadMax = 1
            root.smoothMaxLoad = rawLoadMax
            // 仅当当前标签页是 Load 时才触发滑动
            if (root.currentChartTab === 2) {
                slideAnim.duration = 2000  // medium timer 间隔
                slideAnim.start()
            }
        }
    }
    
    component DualArcGauge: Item {
        id: gauge

        property string titleText: "CPU temp"
        property string gapTitleText: "Usage"
        property real mainValue: 41
        property real secondaryValue: 3
        property string mainSuffix: "°C"
        property string secondarySuffix: "%"
        
        property real mainMax: 100
        property real secondaryMax: 100
        
        // 改进轨道背景底色，摒弃死灰色，采用带原色透光感觉的高级轨道。用户如果不喜欢可以降低透明度。
        property color mainTrackColor: Qt.rgba(mainArcColor.r, mainArcColor.g, mainArcColor.b, 0.15)
        property color secondaryTrackColor: Qt.rgba(secondaryArcColor.r, secondaryArcColor.g, secondaryArcColor.b, 0.15)
        
        property color mainArcColor: Colorscheme.primary
        property color secondaryArcColor: Colorscheme.secondary
        
        implicitWidth: 230
        implicitHeight: 230

        Canvas {
            id: canvas
            anchors.fill: parent
            
            property real mVal: gauge.mainValue
            property real sVal: gauge.secondaryValue
            onMValChanged: requestPaint()
            onSValChanged: requestPaint()
            
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var r = Math.min(width, height) / 2 - 18;
                ctx.lineCap = "round";
                // 变细优化：按照要求将笔刷大幅削减，提供更精致的扁平化视效
                ctx.lineWidth = 9;

                var pi = Math.PI;
                var d2r = pi / 180.0;
                
                // 彻底遵照要求：右下角的缺口是原点！ 45°
                var offsetSmall = 6 * d2r;   // 左上的小缝隙 (调回6度极小缝隙)
                var offsetLarge = 22 * d2r;  // 右下的大缝隙（完美包裹占用率文字）
                
                // T1 (温度赛道, 下半部分): 紧贴右下角缺口的下方(CW 顺时针)延伸到左上
                var t1Base = 45 * d2r + offsetLarge;
                var t1End  = 225 * d2r - offsetSmall;
                
                // T2 (占用率赛道, 上半部分): 遵照要求起点改为对角（左上角缺口的上方）(CW 顺时针)延伸倒挂回右下角
                var t2Base = 225 * d2r + offsetSmall;
                var t2End  = 45 * d2r - offsetLarge + 2 * pi;
                
                // --- 画基础轨道底色 ---
                ctx.beginPath();
                ctx.arc(cx, cy, r, t1Base, t1End, false); // 顺时针
                ctx.strokeStyle = gauge.mainTrackColor;
                ctx.stroke();
                
                ctx.beginPath();
                ctx.arc(cx, cy, r, t2Base, t2End, false); // 顺时针
                ctx.strokeStyle = gauge.secondaryTrackColor;
                ctx.stroke();
                
                // --- 画温度属性 (顺时针生长) ---
                var mainProgress = Math.min(1.0, Math.max(0.0, gauge.mainValue / gauge.mainMax));
                if (mainProgress > 0) {
                    var t1Sweep = t1End - t1Base; 
                    if (t1Sweep < 0) t1Sweep += 2 * pi;
                    var t1ValEnd = t1Base + t1Sweep * mainProgress;
                    
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, t1Base, t1ValEnd, false);
                    ctx.strokeStyle = (gauge.mainValue > 85 && gauge.mainSuffix === "°C") ? Colorscheme.error : gauge.mainArcColor;
                    ctx.stroke();
                }
                
                // --- 画利用率属性 (从左上角顺时针攀爬向右下角) ---
                var secProgress = Math.min(1.0, Math.max(0.0, gauge.secondaryValue / gauge.secondaryMax));
                if (secProgress > 0) {
                    var t2Sweep = t2End - t2Base;
                    if (t2Sweep < 0) t2Sweep += 2 * pi;
                    var t2ValEnd = t2Base + t2Sweep * secProgress;
                    
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, t2Base, t2ValEnd, false);
                    ctx.strokeStyle = gauge.secondaryArcColor;
                    ctx.stroke();
                }
            }
        }
        
        // 1. 中央核心区: 温度
        Column {
            anchors.centerIn: parent
            Text { 
                text: Math.round(gauge.mainValue) + gauge.mainSuffix
                font.pixelSize: Sizes.font.h6; font.family: Sizes.fontFamilyMono; color: Colorscheme.on_surface 
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text { 
                text: gauge.titleText 
                font.pixelSize: Sizes.font.lg; font.family: Sizes.fontFamily; color: Colorscheme.on_surface_variant 
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        
        // 2. 截断区: 利用率文字 (定位精确塞进右下 45度角的大缝隙缺口)
        Item {
            // 利用三角函数定位到圆环半径的 45度角坐标 (45度正弦与余弦均为0.707)
            x: gauge.width / 2 + (Math.min(gauge.width, gauge.height) / 2 - 18) * 0.707
            y: gauge.height / 2 + (Math.min(gauge.width, gauge.height) / 2 - 18) * 0.707
            
            Column {
                anchors.centerIn: parent
                Text { 
                    text: Math.round(gauge.secondaryValue) + gauge.secondarySuffix
                    font.pixelSize: Sizes.font.body; font.family: Sizes.fontFamilyMono; color: Colorscheme.on_surface; font.bold: true 
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text { 
                    text: gauge.gapTitleText
                    font.pixelSize: Sizes.font.xsm; font.family: Sizes.fontFamily; color: Colorscheme.on_surface_variant 
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    property int currentChartTab: 0

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: systemColumn.implicitHeight + 20

        ColumnLayout {
            id: systemColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: Sizes.spacing.section

            // --- Section 1: 创新的双面复合仪表盘区 ---
            Row {
                Layout.fillWidth: true
                spacing: Sizes.spacing.lg
                
                // 完全摒弃 Layout 系统，使用纯原生的宽度平分计算，从根源掐断宽高无限依赖的死循环 (QQuickItem::polish() loop)
                property real itemDim: (width - 16) / 2

                DualArcGauge {
                    width: parent.itemDim
                    height: parent.itemDim
                    
                    titleText: "GPU temp"
                    mainValue: SysmonPlugin.gpuTemp
                    secondaryValue: SysmonPlugin.gpuUsage
                    mainArcColor: Colorscheme.secondary
                    secondaryArcColor: Colorscheme.secondary_fixed_dim
                }
                
                DualArcGauge {
                    width: parent.itemDim
                    height: parent.itemDim
                    
                    titleText: "CPU temp"
                    mainValue: SysmonPlugin.coreTemp
                    secondaryValue: SysmonPlugin.cpuUsage
                    mainArcColor: Colorscheme.primary
                    secondaryArcColor: Colorscheme.primary_fixed_dim
                }
            }

            // --- Section 1.5: 跨界独立 MD3 悬挂胶囊按钮 ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Sizes.spacing.xxs
                
                component TabBtn: Item {
                    property string textStr
                    property int tabIdx
                    property bool isActive: root.currentChartTab === tabIdx
                    property bool isFirst: false
                    property bool isLast: false
                    
                    // 立刻变形：按压即刻轻微扩张拉伸，缩小幅度以显优雅
                    Layout.preferredWidth: 64 + (btnMouse.pressed ? 8 : 0)
                    Layout.preferredHeight: 32
                    
                    // 交界处留有的缝隙：重新赋予它们 4px 的切角倒圆，完美匹配图片设定！按下瞬间彻底独立为 16px
                    property real rLeft: (isActive || isFirst || btnMouse.pressed) ? 16 : 4
                    property real rRight: (isActive || isLast || btnMouse.pressed) ? 16 : 4
                    
                    property color bgColor: isActive ? Colorscheme.primary_container : (btnMouse.containsMouse ? Colorscheme.surface_container_highest : Colorscheme.surface_container)
                    
                    // 稍微延长动画时长，找回微果冻动效的物理松弛感
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on bgColor { ColorAnimation { duration: 150 } }
                    
                    // 双重基座降维打法：底座扛最大圆角，遮罩扛最小锐角压边。完美防漏。
                    
                    // 【底座大圆角】：始终取两端所需的最大弧度。由于它拥有最大的圆角侵占，必定会被拥有较小圆角的遮罩完满覆盖。
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.rLeft > parent.rRight ? parent.rLeft : parent.rRight
                        color: parent.bgColor
                        // 稍微延长变形动画让圆润过渡清晰可见
                        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                    }
                    
                    // 【锐角遮罩】：它只负责去修饰要求圆角较小（更尖锐）的那一边。并且半场长度足够将其自身的微小倒圆隐藏于底座的直线中！
                    Rectangle {
                        // 锚点锁定在要求较小倒角的那一边
                        anchors.left: (parent.rLeft < parent.rRight) ? parent.left : undefined
                        anchors.right: (parent.rRight < parent.rLeft) ? parent.right : undefined
                        
                        // 当两边倒角相同（如完美的大药丸或者同为平端），这个遮罩层自动隐身下岗
                        visible: parent.rLeft !== parent.rRight
                        
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width / 2 + 5 // 安全冗余 5px 以确保另一端的内倾曲线彻底藏在底座中央的平直面上
                        
                        radius: parent.rLeft < parent.rRight ? parent.rLeft : parent.rRight
                        color: parent.bgColor
                        
                        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: parent.textStr
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.md
                        font.bold: parent.isActive
                        color: parent.isActive ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
                        z: 2
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.currentChartTab = parent.tabIdx
                        z: 3
                    }
                }
                
                TabBtn { textStr: "Net"; tabIdx: 0; isFirst: true }
                TabBtn { textStr: "RAM"; tabIdx: 1 }
                TabBtn { textStr: "Load"; tabIdx: 2; isLast: true }
                
                Item { Layout.fillWidth: true }
            }

            // --- Section 2: 折线图 + 右侧信息 ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                Layout.maximumHeight: 104
                spacing: Sizes.spacing.md
                
                // 左侧: 折线图（圆角矩形背景）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 120
                    color: Colorscheme.surface_container_lowest
                    radius: Sizes.rounding.large
                    clip: true
                    
                    SystemChartCanvas {
                        anchors.fill: parent
                        anchors.margins: 8

                        currentTab:    root.currentChartTab
                        slideProgress: root.slideProgress
                        revision:      root.chartRevision

                        netDownHistory: root.netDownHistory
                        netUpHistory:   root.netUpHistory
                        ramHistory:     root.ramHistory
                        load1History:   root.load1History
                        load5History:   root.load5History
                        load15History:  root.load15History

                        smoothMaxNet:  root.smoothMaxNet
                        smoothMaxLoad: root.smoothMaxLoad

                        netDownColor: root.netDownColor
                        netUpColor:   root.netUpColor
                        ramLineColor: root.ramLineColor
                        load1Color:   root.load1Color
                        load5Color:   root.load5Color
                        load15Color:  root.load15Color
                    }
                }
                
                // 右侧: 数据信息（无背景，贴右）
                ColumnLayout {
                    id: chartInfoColumn
                    Layout.preferredWidth: 140
                    Layout.maximumWidth: 140
                    Layout.fillHeight: true
                    spacing: Sizes.spacing.sm
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    clip: true
                    
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s
                        Text { text: "download"; font.family: Sizes.fontIcon; color: root.netDownColor; font.pixelSize: Sizes.font.xl }
                        Text {
                            Layout.fillWidth: true
                            text: formatBytes(SysmonPlugin.netDownBps)
                            color: root.netDownColor
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s
                        Text { text: "upload"; font.family: Sizes.fontIcon; color: root.netUpColor; font.pixelSize: Sizes.font.xl }
                        Text {
                            Layout.fillWidth: true
                            text: formatBytes(SysmonPlugin.netUpBps)
                            color: root.netUpColor
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s
                        Text { text: "memory"; font.family: Sizes.fontIcon; color: root.ramLineColor; font.pixelSize: Sizes.font.xl }
                        Text {
                            Layout.fillWidth: true
                            text: SysmonPlugin.ramUsedGB.toFixed(1) + "/" + SysmonPlugin.ramTotalGB.toFixed(1) + " GiB"
                            color: Colorscheme.on_surface
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Sizes.spacing.s
                        Text { text: "speed"; font.family: Sizes.fontIcon; color: root.load1Color; font.pixelSize: Sizes.font.xl }
                        Text { text: SysmonPlugin.load1.toFixed(2); color: root.load1Color; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.lg; font.bold: true; elide: Text.ElideRight }
                        Text { text: SysmonPlugin.load5.toFixed(2); color: root.load5Color; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md }
                        Text { text: SysmonPlugin.load15.toFixed(2); color: root.load15Color; font.family: Sizes.fontFamilyMono; font.pixelSize: Sizes.font.md }
                    }
                }
            }

            // --- Section 3: 无上限系统属性展示网格矩阵 ---
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 16
                
                component GridCard: Item {
                    property string iconTxt
                    property string title
                    property string val
                    property color acc: Colorscheme.primary
                    
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowContent.height
                    
                    RowLayout {
                        id: rowContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Sizes.spacing.sm
                        
                        Text { Layout.alignment: Qt.AlignVCenter; text: parent.parent.iconTxt; font.family: Sizes.fontIcon; color: parent.parent.acc; font.pixelSize: Sizes.font.xl }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: parent.parent.title + ":"
                            color: Colorscheme.on_surface_variant
                            font.pixelSize: Sizes.font.md
                            font.family: Sizes.fontFamily
                            elide: Text.ElideRight
                        }
                        Text { 
                            Layout.alignment: Qt.AlignVCenter
                            text: parent.parent.val
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignRight
                            color: Colorscheme.on_surface
                            font.pixelSize: Sizes.font.lg
                            font.bold: true
                            font.family: Sizes.fontFamilyMono
                            elide: Text.ElideRight
                        }
                    }
                }
                
                GridCard { iconTxt: "swap_horiz"; title: "Swap"; val: formatGiB(SysmonPlugin.swapUsedGB) + " / " + formatGiB(SysmonPlugin.swapTotalGB); acc: Colorscheme.primary }
                GridCard { iconTxt: "memory"; title: "CPU0 Freq"; val: SysmonPlugin.cpuFreqGHz.toFixed(2) + " GHz"; acc: Colorscheme.secondary_container }
                GridCard { iconTxt: "account_tree"; title: "Tasks"; val: SysmonPlugin.taskRunning + " / " + SysmonPlugin.taskTotal; acc: Colorscheme.tertiary }
                GridCard { iconTxt: "schedule"; title: "Uptime"; val: SysmonPlugin.uptime; acc: Colorscheme.secondary }
            }

            // --- Section 4: 空间体积与电量柱群 ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Sizes.spacing.md
                
                component RootCard: Rectangle {
                    id: rootCard
                    property string title: "Root (/)"
                    property string val: SysmonPlugin.diskUsage.toFixed(1) + "%"
                    property string usageTxt: SysmonPlugin.diskUsedGB.toFixed(0) + " GB / " + SysmonPlugin.diskTotalGB.toFixed(0) + " GB"
                    property real perc: SysmonPlugin.diskUsage / 100.0
                    property color accColor: Colorscheme.tertiary // Mocha Mauve/Purple
                    
                    Layout.fillWidth: true
                    height: 86
                    color: Colorscheme.surface_container_lowest
                    radius: Sizes.rounding.large
                    clip: true
                    
                    // 进度条渲染层 (独立圆角倒圆设计)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * rootCard.perc
                        color: Qt.rgba(rootCard.accColor.r, rootCard.accColor.g, rootCard.accColor.b, 0.15)
                        radius: Sizes.rounding.large // 让填充块本身也具有优美的圆角边界
                    }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: Sizes.spacing.lg
                        
                        // Icon Block
                        Rectangle {
                            width: 50; height: 50; radius: Sizes.rounding.chip 
                            color: Qt.rgba(rootCard.accColor.r, rootCard.accColor.g, rootCard.accColor.b, 0.15)
                            Text { anchors.centerIn: parent; text: "hard_drive_2"; font.family: Sizes.fontIcon; color: rootCard.accColor; font.pixelSize: Sizes.font.h2b }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Sizes.spacing.s
                            
                            RowLayout {
                                Row {
                                    spacing: Sizes.spacing.s
                                    Text {
                                        text: "storage"
                                        font.family: Sizes.fontIcon
                                        color: Colorscheme.on_surface
                                        font.pixelSize: Sizes.font.body
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: rootCard.title
                                        color: Colorscheme.on_surface
                                        font.pixelSize: Sizes.font.body
                                        font.bold: true
                                        font.family: Sizes.fontFamily
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: rootCard.val
                                    color: rootCard.accColor
                                    font.pixelSize: Sizes.font.xxl
                                    font.bold:true
                                    font.family: Sizes.fontFamilyMono
                                    elide: Text.ElideRight
                                }
                            }
                            RowLayout {
                                Text { text: "Used Space:"; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.md; font.family: Sizes.fontFamily }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: rootCard.usageTxt
                                    color: Colorscheme.on_surface_variant
                                    font.pixelSize: Sizes.font.md
                                    font.family: Sizes.fontFamilyMono
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                
                component BatteryCard: Rectangle {
                    id: batCard
                    property string val: SysmonPlugin.batteryPercent.toFixed(1) + "%"
                    property real perc: SysmonPlugin.batteryPercent / 100.0
                    property string statusTxt: SysmonPlugin.batteryStatus
                    property int healthNum: SysmonPlugin.batteryHealth
                    property string powerTxt: SysmonPlugin.batteryPowerW.toFixed(1) + " W"
                    property color accColor: Colorscheme.secondary // Mocha Green
                    
                    // 基于健康度动态分配警戒颜色
                    property color healthColor: healthNum >= 80 ? Colorscheme.secondary : (healthNum >= 60 ? Colorscheme.secondary_container : Colorscheme.tertiary_container)
                    
                    Layout.fillWidth: true
                    height: 86
                    color: Colorscheme.surface_container_lowest
                    radius: Sizes.rounding.large
                    clip: true
                    
                    // 进度条渲染层 (独立圆角倒圆设计)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * batCard.perc
                        color: Qt.rgba(batCard.accColor.r, batCard.accColor.g, batCard.accColor.b, 0.15)
                        radius: Sizes.rounding.large // 同样引入独占大圆角
                    }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: Sizes.spacing.lg
                        
                        Rectangle {
                            width: 50; height: 50; radius: Sizes.rounding.chip
                            color: Qt.rgba(batCard.accColor.r, batCard.accColor.g, batCard.accColor.b, 0.15)
                            Text { anchors.centerIn: parent; text: "battery_charging_full"; font.family: Sizes.fontIcon; color: batCard.accColor; font.pixelSize: Sizes.font.h2b }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Sizes.spacing.s
                            
                            RowLayout {
                                // “System Battery” 被替换为根据健康度染色的硬核纯数字百分比，并且大幅增加了字号
                                Text {
                                    text: batCard.healthNum + "%"
                                    color: batCard.healthColor
                                    font.pixelSize: Sizes.font.display
                                    font.bold: true
                                    font.family: Sizes.fontFamilyMono
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: batCard.val
                                    color: batCard.accColor
                                    font.pixelSize: Sizes.font.xxl
                                    font.bold:true
                                    font.family: Sizes.fontFamilyMono
                                    elide: Text.ElideRight
                                }
                            }
                            RowLayout {
                                Text { 
                                    text: batCard.statusTxt
                                    color: batCard.statusTxt === "Charging" ? batCard.accColor : Colorscheme.on_surface_variant
                                    font.pixelSize: Sizes.font.md
                                    font.family: Sizes.fontFamily
                                    font.bold: batCard.statusTxt === "Charging"
                                    elide: Text.ElideRight
                                }
                                Item { Layout.fillWidth: true }
                                // 右下部分移除冗余文字，单独留存瓦数功率
                                Text {
                                    text: batCard.powerTxt
                                    color: Colorscheme.on_surface_variant
                                    font.pixelSize: Sizes.font.md
                                    font.family: Sizes.fontFamilyMono
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                
                RootCard {}
                BatteryCard {}
            }

            // --- Section 5: 进程监控视图 ---
            ColumnLayout {
                id: procSection
                Layout.fillWidth: true
                Layout.preferredHeight: 420
                Layout.minimumHeight: 420
                spacing: Sizes.spacing.md
                
                // 右键菜单打开时暂停刷新
                property bool procMenuOpen: false
                property int expandedPid: -1
                property int detailLoadingPid: -1
                property var procDetailsCache: ({})

                Timer {
                    interval: 3000
                    running: procSection.expandedPid > 0 && !procSection.procMenuOpen
                    repeat: true
                    onTriggered: procSection.requestDetail(procSection.expandedPid, true)
                }
                
                // 分类/排序/搜索状态
                property int procTabIdx: 0    // 0=全部, 1=用户, 2=系统
                property int sortCol: 0       // 0=CPU, 1=RSS, 2=PID
                property bool sortAsc: false
                property string searchText: ""
                
                // JS 过滤+排序+搜索引擎
                function getFilteredProcesses() {
                    var result = []
                    var procModel = SysmonPlugin.processes
                    if (!procModel) return result
                    var count = 0
                    if (typeof procModel.count === "function")
                        count = procModel.count()
                    else if (procModel.count !== undefined)
                        count = procModel.count
                    
                    for (var i = 0; i < count; i++) {
                        var item = procModel.get(i)
                        if (!item || !item.name) continue
                        
                        // 分类过滤
                        var itemUid = (item.uid !== undefined) ? item.uid : 1000
                        if (procSection.procTabIdx === 1 && itemUid < 1000) continue  // 用户进程: UID >= 1000
                        if (procSection.procTabIdx === 2 && itemUid >= 1000) continue // 系统进程: UID < 1000
                        
                        // 搜索过滤
                        if (procSection.searchText.length > 0) {
                            var query = procSection.searchText.toLowerCase()
                            var nameMatch = item.name.toLowerCase().indexOf(query) >= 0
                            var pidMatch = String(item.pid).indexOf(query) >= 0
                            var cmdMatch = item.cmdline ? item.cmdline.toLowerCase().indexOf(query) >= 0 : false
                            if (!nameMatch && !pidMatch && !cmdMatch) continue
                        }
                        
                        result.push(item)
                    }
                    
                    // 排序
                    var col = procSection.sortCol
                    var asc = procSection.sortAsc
                    result.sort(function(a, b) {
                        var va, vb
                        if (col === 0) { va = a.cpuPercent; vb = b.cpuPercent }
                        else if (col === 1) { va = a.memKB; vb = b.memKB }
                        else { va = a.pid; vb = b.pid }
                        return asc ? (va - vb) : (vb - va)
                    })
                    
                    return result
                }
                
                ListModel {
                    id: processListModel
                }

                function sameProcessItem(a, b) {
                    if (!a || !b) return false
                    return a.pid === b.pid
                        && a.name === b.name
                        && a.cpuPercent === b.cpuPercent
                        && a.memKB === b.memKB
                        && a.uid === b.uid
                        && a.cmdline === b.cmdline
                }

                function detailForPid(pid) {
                    if (!pid) return null
                    return procDetailsCache[String(pid)] || null
                }

                function storeDetail(pid, detail) {
                    const next = Object.assign({}, procDetailsCache)
                    next[String(pid)] = detail
                    procDetailsCache = next
                }

                function requestDetail(pid, forceRefresh) {
                    if (!pid) return
                    if (detailLoadingPid === pid) return
                    const cached = detailForPid(pid)
                    if (cached && !forceRefresh)
                        return

                    detailLoadingPid = pid
                    const detail = SysmonPlugin.getProcessDetails(pid)
                    storeDetail(pid, detail)
                    if (detailLoadingPid === pid)
                        detailLoadingPid = -1
                }

                function toggleExpanded(pid) {
                    if (!pid) return
                    if (expandedPid === pid) {
                        expandedPid = -1
                        detailLoadingPid = -1
                        return
                    }

                    expandedPid = pid
                    requestDetail(pid, true)
                }

                function syncProcessListModel(items) {
                    const next = items || []

                    if (expandedPid > 0) {
                        let stillVisible = false
                        for (let i = 0; i < next.length; ++i) {
                            if (next[i] && next[i].pid === expandedPid) {
                                stillVisible = true
                                break
                            }
                        }
                        if (!stillVisible) {
                            expandedPid = -1
                            detailLoadingPid = -1
                        }
                    }

                    while (processListModel.count > next.length)
                        processListModel.remove(processListModel.count - 1, 1)

                    for (let i = 0; i < next.length; ++i) {
                        const row = next[i]
                        if (i >= processListModel.count) {
                            processListModel.append(row)
                        } else {
                            const cur = processListModel.get(i)
                            if (!sameProcessItem(cur, row))
                                processListModel.set(i, row)
                        }
                    }
                }

                function updateFilteredProcesses(preserveScroll) {
                    if (!preserveScroll || !processList) {
                        procSection.syncProcessListModel(procSection.getFilteredProcesses())
                        return
                    }

                    var prevY = processList.contentY
                    var prevMax = Math.max(0, processList.contentHeight - processList.height)
                    procSection.syncProcessListModel(procSection.getFilteredProcesses())

                    Qt.callLater(function() {
                        if (!processList) return
                        var nextMax = Math.max(0, processList.contentHeight - processList.height)
                        var targetY = prevY
                        if (prevMax > 0 && nextMax > 0)
                            targetY = (prevY / prevMax) * nextMax
                        processList.contentY = Math.max(0, Math.min(nextMax, targetY))
                    })
                }
                
                Component.onCompleted: procSection.updateFilteredProcesses(false)
                
                Connections {
                    target: SysmonPlugin
                    function onFastDataChanged() {
                        if (!procSection.procMenuOpen) {
                            procSection.updateFilteredProcesses(true)
                        }
                    }
                }
                
                // 分类/排序/搜索变化时立即刷新
                onProcTabIdxChanged: procSection.updateFilteredProcesses(false)
                onSortColChanged: procSection.updateFilteredProcesses(false)
                onSortAscChanged: procSection.updateFilteredProcesses(false)
                onSearchTextChanged: procSection.updateFilteredProcesses(false)
                
                // --- 头部 1: 控制栏 ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Sizes.spacing.sm
                    
                    Text { text: "leaderboard"; font.family: Sizes.fontIcon; color: Colorscheme.primary; font.pixelSize: Sizes.font.h1 }
                    Text { text: "进程"; color: Colorscheme.on_surface; font.pixelSize: Sizes.font.xl; font.bold: true; font.family: Sizes.fontFamily }
                    
                    Item { Layout.preferredWidth: 8 }
                    
                    RowLayout {
                        spacing: Sizes.spacing.xxs
                        
                        component ProcBtn: Item {
                            property string textStr
                            property int tabIdx
                            property bool isActive: procSection.procTabIdx === tabIdx
                            property bool isFirst: false
                            property bool isLast: false
                            
                            Layout.preferredWidth: 44 + (isLast ? 18 : 0)
                            Layout.preferredHeight: 30
                            
                            property real rLeft: isActive ? 15 : 8
                            property real rRight: isActive ? 15 : 8
                            
                            property color bgColor: isActive ? Colorscheme.primary_container : (btnMouse.containsMouse ? Colorscheme.surface_container_highest : Colorscheme.surface_container)
                            
                            Behavior on bgColor { ColorAnimation { duration: 150 } }
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.rLeft > parent.rRight ? parent.rLeft : parent.rRight
                                color: parent.bgColor
                                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                            }
                            
                            Rectangle {
                                anchors.left: (parent.rLeft < parent.rRight) ? parent.left : undefined
                                anchors.right: (parent.rRight < parent.rLeft) ? parent.right : undefined
                                visible: parent.rLeft !== parent.rRight
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: parent.width / 2 + 5 
                                radius: parent.rLeft < parent.rRight ? parent.rLeft : parent.rRight
                                color: parent.bgColor
                                Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutSine } }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: parent.textStr
                                font.family: Sizes.fontFamily
                                font.pixelSize: Sizes.font.sm
                                font.bold: parent.isActive
                                color: parent.isActive ? Colorscheme.on_primary_container : Colorscheme.on_surface_variant
                                z: 2
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: procSection.procTabIdx = parent.tabIdx
                                z: 3
                            }
                        }
                        
                        ProcBtn { textStr: "全部"; tabIdx: 0; isFirst: true }
                        ProcBtn { textStr: "用户"; tabIdx: 1 }
                        ProcBtn { textStr: "系统工具"; tabIdx: 2; isLast: true }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Search bar - 使用 TextField 替代 TextInput 以获得完整的键盘输入支持
                    Rectangle {
                        id: searchBar
                        Layout.fillWidth: true
                        Layout.minimumWidth: 96
                        Layout.maximumWidth: 132
                        Layout.preferredHeight: 30
                        radius: Sizes.rounding.chipPlus
                        color: Colorscheme.surface_container_highest
                        border.color: searchInput.activeFocus ? Colorscheme.secondary : Colorscheme.primary
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: Sizes.spacing.s
                            Text { text: "search"; font.family: Sizes.fontIcon; color: Colorscheme.primary; font.pixelSize: Sizes.font.xl }
                            TextField {
                                id: searchInput
                                Layout.fillWidth: true
                                color: Colorscheme.on_surface
                                font.pixelSize: Sizes.font.sm
                                font.family: Sizes.fontFamily
                                placeholderText: ""
                                background: Item {}
                                padding: 0
                                topPadding: 0
                                bottomPadding: 0
                                onTextChanged: procSection.searchText = text
                            }
                        }
                    }
                }
                
                // --- 进程列表主容器 ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 360
                    Layout.minimumHeight: 360
                    color: Colorscheme.surface_container_lowest
                    radius: Sizes.rounding.large
                    clip: true
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: Sizes.spacing.md
                        
                        // Header 2 (表头) - 排序按钮
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Sizes.spacing.sm
                            Text { text: "名称"; color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.md; font.family: Sizes.fontFamily; Layout.fillWidth: true }
                            
                            component SortHeader: Rectangle {
                                property string title
                                property int colIdx
                                property bool isActive: procSection.sortCol === colIdx
                                
                                Layout.preferredWidth: colIdx === 0 ? 80 : (colIdx === 1 ? 100 : 70)
                                height: 26
                                radius: Sizes.rounding.normalPlus
                                color: isActive ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.2) : (sortHoverMouse.containsMouse ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.08) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Sizes.spacing.xs
                                    Text { 
                                        text: parent.parent.title
                                        color: parent.parent.isActive ? Colorscheme.primary : Colorscheme.on_surface_variant
                                        font.pixelSize: Sizes.font.md
                                        font.family: Sizes.fontFamily
                                        font.bold: parent.parent.isActive 
                                    }
                                    Text { 
                                        text: procSection.sortAsc ? "arrow_upward" : "arrow_downward"
                                        font.family: Sizes.fontIcon
                                        color: Colorscheme.primary
                                        font.pixelSize: Sizes.font.lg
                                        visible: parent.parent.isActive
                                    }
                                }
                                
                                MouseArea {
                                    id: sortHoverMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (procSection.sortCol === parent.colIdx) {
                                            procSection.sortAsc = !procSection.sortAsc
                                        } else {
                                            procSection.sortCol = parent.colIdx
                                            procSection.sortAsc = false
                                        }
                                    }
                                }
                            }
                            
                            SortHeader { title: "CPU"; colIdx: 0 }
                            SortHeader { title: "RSS"; colIdx: 1 }
                            SortHeader { title: "PID"; colIdx: 2 }
                        }
                        
                        Rectangle { Layout.fillWidth: true; height: 1; color: Colorscheme.surface_container_highest }
                        
                        // 列表区域
                        ListView {
                            id: processList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Sizes.spacing.xs
                            interactive: true

                            model: processListModel
                            
                            delegate: Rectangle {
                                id: procDelegate
                                width: processList.width
                                implicitHeight: 42 + (expanded ? detailCard.implicitHeight + 8 : 0)
                                height: implicitHeight
                                radius: Sizes.rounding.small
                                
                                // ListModel 中角色作为直接属性暴露，需手动组装
                                property var proc: ({pid: pid, name: name, cpuPercent: cpuPercent, memKB: memKB, uid: uid, cmdline: cmdline})
                                
                                readonly property bool expanded: proc && proc.pid === procSection.expandedPid
                                readonly property var detail: proc ? procSection.detailForPid(proc.pid) : null
                                readonly property bool loadingDetail: proc && proc.pid === procSection.detailLoadingPid
                                property bool cpuHigh: (proc && proc.cpuPercent ? proc.cpuPercent : 0) > 5.0
                                property bool ramHigh: (proc && proc.memKB ? proc.memKB : 0) > 1048576
                                property bool hovered: procMouse.containsMouse
                                
                                // 悬浮时使用半透明主题色填充
                                color: expanded
                                    ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.14)
                                    : (hovered ? Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.12) : "transparent")
                                
                                Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                
                                Column {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: expanded ? 8 : 0

                                    RowLayout {
                                        width: parent.width
                                        height: 42
                                        spacing: Sizes.spacing.sm

                                        Text { 
                                            text: proc && proc.name ? proc.name : ""
                                            color: Colorscheme.on_surface; font.pixelSize: Sizes.font.lg
                                            font.family: Sizes.fontFamilyMono
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 80; height: 26; radius: Sizes.rounding.normalPlus
                                            color: cpuHigh 
                                                ? Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.15) 
                                                : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                                            Text { 
                                                anchors.centerIn: parent
                                                text: (proc && proc.cpuPercent ? proc.cpuPercent : 0).toFixed(1) + "%"
                                                color: cpuHigh ? Colorscheme.error : Colorscheme.on_surface_variant
                                                font.pixelSize: Sizes.font.md; font.family: Sizes.fontFamilyMono; font.bold: true 
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 100; height: 26; radius: Sizes.rounding.normalPlus
                                            color: ramHigh 
                                                ? Qt.rgba(Colorscheme.error.r, Colorscheme.error.g, Colorscheme.error.b, 0.15) 
                                                : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.06)
                                            Text { 
                                                anchors.centerIn: parent
                                                text: formatMemKB(proc && proc.memKB ? proc.memKB : 0)
                                                color: ramHigh ? Colorscheme.error : Colorscheme.on_surface_variant
                                                font.pixelSize: Sizes.font.md; font.family: Sizes.fontFamilyMono; font.bold: true 
                                            }
                                        }

                                        Text { 
                                            text: proc && proc.pid ? proc.pid : ""
                                            color: Colorscheme.on_surface_variant; font.pixelSize: Sizes.font.lg
                                            font.family: Sizes.fontFamilyMono
                                            Layout.preferredWidth: 70; horizontalAlignment: Text.AlignHCenter 
                                        }
                                    }

                                    Rectangle {
                                        id: detailCard
                                        width: parent.width
                                        implicitHeight: detailColumn.implicitHeight + 14
                                        height: expanded ? implicitHeight : 0
                                        visible: expanded || height > 0
                                        radius: Sizes.rounding.normal
                                        clip: true
                                        color: Qt.rgba(Colorscheme.surface_container_highest.r, Colorscheme.surface_container_highest.g, Colorscheme.surface_container_highest.b, 0.82)

                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                        Column {
                                            id: detailColumn
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 10
                                            spacing: 8

                                            Text {
                                                width: parent.width
                                                visible: loadingDetail
                                                text: "正在读取 smaps_rollup..."
                                                color: Colorscheme.on_surface_variant
                                                font.pixelSize: Sizes.font.sm
                                                font.family: Sizes.fontFamily
                                            }

                                            component DetailChip: Rectangle {
                                                property string title: ""
                                                property string value: ""

                                                color: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.05)
                                                radius: Sizes.rounding.normalPlus
                                                implicitWidth: chipRow.implicitWidth + 16
                                                implicitHeight: chipRow.implicitHeight + 8

                                                Row {
                                                    id: chipRow
                                                    anchors.centerIn: parent
                                                    spacing: 6

                                                    Text {
                                                        text: parent.parent.title
                                                        color: Colorscheme.on_surface_variant
                                                        font.pixelSize: Sizes.font.xsm
                                                        font.family: Sizes.fontFamily
                                                    }
                                                    Text {
                                                        text: parent.parent.value
                                                        color: Colorscheme.on_surface
                                                        font.pixelSize: Sizes.font.sm
                                                        font.bold: true
                                                        font.family: Sizes.fontFamilyMono
                                                    }
                                                }
                                            }

                                            Flow {
                                                width: parent.width
                                                visible: !loadingDetail && !!detail
                                                spacing: Sizes.spacing.sm

                                                DetailChip { title: "PSS"; value: formatMemKB(detail && detail.pssKB ? detail.pssKB : 0) }
                                                DetailChip { title: "USS"; value: formatMemKB(detail && detail.ussKB ? detail.ussKB : 0) }
                                                DetailChip { title: "RSS"; value: formatMemKB(detail && detail.rssKB ? detail.rssKB : (proc && proc.memKB ? proc.memKB : 0)) }
                                                DetailChip { title: "Threads"; value: String(detail && detail.threads ? detail.threads : 0) }
                                            }

                                            Text {
                                                width: parent.width
                                                visible: !loadingDetail && !!detail
                                                text: detail && detail.exactMemory
                                                    ? "真值来自 smaps_rollup，USS = Private_Clean + Private_Dirty"
                                                    : (detail && detail.permissionDenied
                                                        ? "无权限读取 smaps_rollup；这里只能显示基础信息，不能给出该进程的 PSS/USS 真值"
                                                        : "该进程详情暂不可用")
                                                color: detail && detail.exactMemory ? Colorscheme.secondary : Colorscheme.error
                                                font.pixelSize: Sizes.font.xsm
                                                font.family: Sizes.fontFamily
                                                wrapMode: Text.Wrap
                                            }

                                            Flow {
                                                width: parent.width
                                                visible: !loadingDetail && !!detail && detail.exactMemory
                                                spacing: Sizes.spacing.sm

                                                DetailChip { title: "Private"; value: formatMemKB((detail && detail.privateCleanKB ? detail.privateCleanKB : 0) + (detail && detail.privateDirtyKB ? detail.privateDirtyKB : 0)) }
                                                DetailChip { title: "Shared"; value: formatMemKB((detail && detail.sharedCleanKB ? detail.sharedCleanKB : 0) + (detail && detail.sharedDirtyKB ? detail.sharedDirtyKB : 0)) }
                                                DetailChip { title: "Anon"; value: formatMemKB(detail && detail.anonymousKB ? detail.anonymousKB : 0) }
                                                DetailChip { title: "Swap"; value: formatMemKB(detail && detail.swapKB ? detail.swapKB : 0) }
                                            }

                                            Text {
                                                width: parent.width
                                                visible: !loadingDetail && !!detail && !!detail.state
                                                text: detail && detail.state ? "状态: " + detail.state + "    EXE: " + (detail.exePath || "--") : ""
                                                color: Colorscheme.on_surface_variant
                                                font.pixelSize: Sizes.font.xsm
                                                font.family: Sizes.fontFamilyMono
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                width: parent.width
                                                visible: !loadingDetail && ((detail && detail.cmdline) || (proc && proc.cmdline))
                                                text: detail && detail.cmdline ? detail.cmdline : (proc && proc.cmdline ? proc.cmdline : "")
                                                color: Colorscheme.on_surface_variant
                                                font.pixelSize: Sizes.font.xsm
                                                font.family: Sizes.fontFamilyMono
                                                wrapMode: Text.WrapAnywhere
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                                
                                MouseArea {
                                    id: procMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            procSection.procMenuOpen = true
                                            procMenu.popup()
                                        } else if (mouse.button === Qt.LeftButton) {
                                            procSection.toggleExpanded(proc.pid)
                                        }
                                    }
                                }
                                
                                Menu {
                                    id: procMenu
                                    
                                    onClosed: procSection.procMenuOpen = false
                                    
                                    background: Rectangle {
                                        implicitWidth: 200
                                        color: Colorscheme.surface_container_high
                                        radius: Sizes.rounding.normal
                                    }
                                    
                                    component ProcMenuItem: MenuItem {
                                        id: mItem
                                        property string iconTxt
                                        contentItem: RowLayout {
                                            spacing: Sizes.spacing.md
                                            Text { text: mItem.iconTxt; font.family: Sizes.fontIcon; color: mItem.enabled ? Colorscheme.on_surface_variant : Colorscheme.outline; font.pixelSize: Sizes.font.xl }
                                            Text { text: mItem.text; color: mItem.enabled ? Colorscheme.on_surface : Colorscheme.outline; font.pixelSize: Sizes.font.md; font.family: Sizes.fontFamily }
                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                    
                                    ProcMenuItem { 
                                        text: "复制进程ID"; iconTxt: "tag"
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["wl-copy", String(proc.pid)])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "复制名称"; iconTxt: "content_copy"
                                        onTriggered: {
                                            if (proc && proc.name) Quickshell.execDetached(["wl-copy", proc.name])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "复制完整命令"; iconTxt: "code"
                                        onTriggered: {
                                            if (proc && proc.cmdline) Quickshell.execDetached(["wl-copy", proc.cmdline])
                                        } 
                                    }
                                    
                                    MenuSeparator {
                                        contentItem: Rectangle { implicitWidth: 180; implicitHeight: 1; color: Colorscheme.outline_variant; anchors.centerIn: parent }
                                    }
                                    
                                    ProcMenuItem { 
                                        text: "结束进程"; iconTxt: "close"
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["kill", String(proc.pid)])
                                        }
                                    }
                                    ProcMenuItem { 
                                        text: "强制结束 (SIGKILL)"; iconTxt: "cancel"
                                        enabled: proc && proc.uid !== undefined && proc.uid >= 1000
                                        onTriggered: {
                                            if (proc && proc.pid) Quickshell.execDetached(["kill", "-9", String(proc.pid)])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
        }
    }
}
}

