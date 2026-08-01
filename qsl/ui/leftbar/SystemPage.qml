// SystemPage — 轻量系统页
// 大胶囊进度（CPU/GPU/MEM/磁盘/电池）+ 2×2 信息卡 + 胶囊进程行
// 无 Canvas / 无曲线；进页 Sysmon.detailActive；齿轮 → kitty btop
//
// 性能：关页停进程轮询；ListView reuseItems + Layout.fillHeight；无展开 smaps

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    signal requestClose()

    property int procFilter: 1
    property int sortCol: 0
    property bool sortAsc: false
    property int menuPid: -1
    property int menuUid: 0
    property real menuX: 0
    property real menuY: 0
    property bool menuOpen: false
    // 筛选/排序结果缓存，避免每次绑定重算 50 项
    property var displayProcesses: []

    readonly property color cpuColor: Color.primary
    readonly property color memColor: Color.secondary
    readonly property color pidColor: Color.tertiary

    function rebuildProcesses() {
        const src = Sysmon.processes || []
        const out = []
        for (let i = 0; i < src.length; i++) {
            const p = src[i]
            if (!p)
                continue
            const uid = (p.uid !== undefined && p.uid !== null) ? Number(p.uid) : 1000
            if (root.procFilter === 1 && uid < 1000)
                continue
            out.push(p)
        }
        out.sort((a, b) => {
            let av = 0
            let bv = 0
            if (root.sortCol === 1) {
                av = Number(a.memory_kb) || 0
                bv = Number(b.memory_kb) || 0
            } else if (root.sortCol === 2) {
                av = Number(a.pid) || 0
                bv = Number(b.pid) || 0
            } else {
                av = Number(a.cpu_percent) || 0
                bv = Number(b.cpu_percent) || 0
            }
            if (av === bv)
                return 0
            const cmp = av < bv ? -1 : 1
            return root.sortAsc ? cmp : -cmp
        })
        displayProcesses = out
    }

    onProcFilterChanged: rebuildProcesses()
    onSortColChanged: rebuildProcesses()
    onSortAscChanged: rebuildProcesses()

    Connections {
        target: Sysmon
        function onProcessesChanged() { root.rebuildProcesses() }
    }

    function setSort(col) {
        if (sortCol === col)
            sortAsc = !sortAsc
        else {
            sortCol = col
            sortAsc = false
        }
    }

    function openMenu(pid, uid, x, y) {
        menuPid = pid
        menuUid = uid
        menuX = x
        menuY = y
        menuOpen = true
    }

    function closeMenu() {
        menuOpen = false
        menuPid = -1
    }

    function batStatusText() {
        if (Battery.charging)
            return "充电中"
        if (Battery.discharging)
            return "放电中"
        if (Battery.fullyCharged)
            return "已充满"
        return "空闲"
    }

    Component.onCompleted: {
        Sysmon.setDetailActive(true)
        rebuildProcesses()
    }
    Component.onDestruction: {
        closeMenu()
        Sysmon.setDetailActive(false)
    }

    // 大胶囊：进度 z0；文案 z1。短进度强制 minWidth=2*radius，圆角始终等于容器，避免「小胶囊鼓边」
    component FillCapsule: Rectangle {
        id: cap
        property string title: ""
        property string iconName: ""
        property string primaryText: ""
        property string secondaryText: ""
        property real fraction: 0
        property real fraction2: 0
        property color accent: Color.primary
        property color accent2: Color.withAlpha(Color.primary, 0.28)
        property bool dual: false
        property bool show: true
        // 趋势曲线：给了数据才画，纵轴固定 0–100（这几项都是百分比）
        property var history: []

        visible: show
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Size.rounding.lg
        color: Color.surfaceHigh
        border.width: Style.border.width
        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
        clip: true

        // 有占用时至少 2*radius 宽，圆角才能与父容器一致
        readonly property real minBar: radius * 2
        function barWidth(frac) {
            const f = Math.max(0, Math.min(1, frac))
            if (f <= 0 || width <= 0)
                return 0
            const raw = width * f
            return Math.min(width, Math.max(cap.minBar, raw))
        }

        readonly property real fillW: dual
            ? barWidth(fraction + fraction2)
            : barWidth(fraction)
        readonly property real appW: dual ? barWidth(fraction) : 0

        Rectangle {
            z: 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: cap.fillW
            visible: width > 0
            radius: cap.radius
            color: cap.dual ? cap.accent2 : Color.withAlpha(cap.accent, 0.18)
        }
        Rectangle {
            z: 0
            visible: cap.dual && width > 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: cap.appW
            radius: cap.radius
            color: Color.withAlpha(cap.accent, 0.35)
        }

        RowLayout {
            z: 1
            anchors.fill: parent
            anchors.margins: Size.spacing.sm
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            spacing: Size.spacing.sm

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Size.rounding.md
                color: Color.surfaceHighest
                border.width: 1
                border.color: Color.withAlpha(cap.accent, 0.35)
                Text {
                    anchors.centerIn: parent
                    text: cap.iconName
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.lg
                    color: cap.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: cap.title
                        color: Color.text
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: cap.primaryText
                        color: cap.accent
                        font.pixelSize: Size.fontSize.lg
                        font.bold: true
                        font.family: Size.fontMono
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: cap.secondaryText
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.sm
                    elide: Text.ElideRight
                }
            }

            // 暗底由 Sparkline 自己画：内存胶囊的进度条会一路铺到最右，
            // 曲线画在浅色填充上会糊掉，垫一层才有稳定对比度。
            // 圆角也交给它——外层套 Rectangle 的话，Item.clip 只裁矩形，
            // 填充区的下面两个角会溢出到圆角外面。
            Sparkline {
                Layout.preferredWidth: 68
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                visible: cap.history.length > 1
                values: cap.history
                maxValue: 100
                lineColor: cap.accent
                cornerRadius: Size.rounding.sm
                backgroundColor: Color.withAlpha(Color.background, 0.45)
            }
        }
    }

    // 单行：左标题 · 右短数值
    component InfoCapsule: Rectangle {
        id: info
        property string title: ""
        property string value: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 48
        radius: Size.rounding.lg
        color: Color.surfaceHigh
        border.width: Style.border.width
        border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            spacing: Size.spacing.sm

            Text {
                text: info.title
                color: Color.textMuted
                font.pixelSize: Size.fontSize.sm
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: implicitWidth
            }
            Item { Layout.fillWidth: true }
            Text {
                text: info.value
                color: Color.text
                font.pixelSize: Size.fontSize.md
                font.bold: true
                font.family: Size.fontMono
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignVCenter
                // 短文案不 elide，避免 ↓/数字被裁成 ...
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        // 工具行
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            Text {
                text: "系统"
                color: Color.text
                font.pixelSize: Size.fontSize.lg
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: !Sysmon.daemonOk && Sysmon.detailActive
                text: "sysmond 未启动"
                color: Color.error
                font.pixelSize: Size.fontSize.sm
            }
            Rectangle {
                width: 40
                height: 40
                radius: Size.rounding.md
                color: btopMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.title
                    color: Color.textMuted
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sysmon.openBtop()
                        root.requestClose()
                    }
                }
            }
        }

        // 上：CPU / GPU / 内存
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            FillCapsule {
                title: "CPU"
                iconName: "speed"
                primaryText: Sysmon.cpuPercent.toFixed(1) + "%"
                secondaryText: Sysmon.cpuTemp > 0
                    ? (Math.round(Sysmon.cpuTemp) + "°C")
                    : "占用"
                fraction: Sysmon.cpuPercent / 100
                accent: Sysmon.cpuTemp > 85 ? Color.error : root.cpuColor
                history: Sysmon.cpuHistory
            }
            FillCapsule {
                show: Sysmon.gpuAvailable
                title: "GPU"
                iconName: "developer_board"
                primaryText: Sysmon.gpuPercent.toFixed(0) + "%"
                secondaryText: Sysmon.gpuTemp > 0
                    ? (Math.round(Sysmon.gpuTemp) + "°C")
                    : "占用"
                fraction: Sysmon.gpuPercent / 100
                accent: Sysmon.gpuTemp > 85 ? Color.error : Color.secondary
                history: Sysmon.gpuHistory
            }
            FillCapsule {
                title: "内存"
                iconName: "memory"
                primaryText: Sysmon.ramUsedGB.toFixed(1) + " / " + Sysmon.ramTotalGB.toFixed(1) + " GiB"
                secondaryText: "使用 "
                    + Sysmon.ramAppGB.toFixed(1) + "  ·  缓存 "
                    + Sysmon.ramCacheGB.toFixed(1) + " GiB"
                dual: true
                fraction: Sysmon.ramTotalGB > 0 ? (Sysmon.ramAppGB / Sysmon.ramTotalGB) : 0
                fraction2: Sysmon.ramTotalGB > 0 ? (Sysmon.ramCacheGB / Sysmon.ramTotalGB) : 0
                accent: root.memColor
                accent2: Color.withAlpha(root.memColor, 0.22)
                history: Sysmon.memHistory
            }
        }

        // 中：网络双曲线 + 压力 + Swap/Uptime
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            // 网络：上下行各一条，共用同一纵轴（按近期峰值自适应），
            // 否则两条各自归一化，视觉上会把 1 K/s 画得和 10 M/s 一样高。
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 78
                radius: Size.rounding.lg
                color: Color.surfaceHigh
                border.width: Style.border.width
                border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Size.spacing.md
                    anchors.rightMargin: Size.spacing.md
                    anchors.topMargin: Size.spacing.sm
                    anchors.bottomMargin: Size.spacing.sm
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Size.spacing.sm

                        Text {
                            text: "网络"
                            color: Color.textMuted
                            font.pixelSize: Size.fontSize.sm
                        }
                        Text {
                            text: Sysmon.netIface
                            color: Color.withAlpha(Color.textMuted, 0.7)
                            font.pixelSize: Size.fontSize.xsm
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillWidth: true }
                        // 纵轴量程放在标题行，压在曲线上会被尖峰撞到
                        Text {
                            text: Sysmon.netPeak > 0
                                ? ("峰值 " + Sysmon.formatBytes(Sysmon.netPeak))
                                : ""
                            color: Color.withAlpha(Color.textMuted, 0.6)
                            font.pixelSize: Size.fontSize.xsm
                        }
                        Text {
                            text: "↓ " + Sysmon.formatBytes(Sysmon.netDownBps)
                            color: root.cpuColor
                            font.pixelSize: Size.fontSize.sm
                            font.bold: true
                            font.family: Size.fontMono
                        }
                        Text {
                            text: "↑ " + Sysmon.formatBytes(Sysmon.netUpBps)
                            color: Color.tertiary
                            font.pixelSize: Size.fontSize.sm
                            font.bold: true
                            font.family: Size.fontMono
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Sparkline {
                            anchors.fill: parent
                            values: Sysmon.netDownHistory
                            overrideMax: Sysmon.netPeak
                            lineColor: root.cpuColor
                        }
                        Sparkline {
                            anchors.fill: parent
                            values: Sysmon.netUpHistory
                            overrideMax: Sysmon.netPeak
                            lineColor: Color.tertiary
                            fillOpacity: 0.10
                        }
                    }
                }
            }

            // 压力（PSI）取代 Load：0–100 的百分比，直接读作
            // 「过去 10 秒有多少时间被卡住」，且 CPU / IO / 内存分得清。
            //
            // 健康系统上这三个数几乎恒为 0——这正是它有用的地方，但光看
            // 一个 0.0 等于没有。所以每项都配一条历史曲线（自适应量程，
            // minSpan 兜底避免把 0.02 的噪声放大成大波浪），
            // 并在近期出现过明显尖峰时才把峰值数字显示出来。
            Rectangle {
                id: psiCard

                // 三项里最坏的近期峰值。用峰值而非当前值做展开条件：
                // 卡顿过去后详情还会多留一会儿（直到尖峰滑出 60 点环形缓冲），
                // 否则等你低头看时它已经收回去了。
                readonly property real worstPeak: Math.max(
                    Sysmon.psiCpuPeak, Sysmon.psiIoPeak, Sysmon.psiMemPeak)
                // 1% 即「10 秒里有 100ms 被卡住」，低于此不值得占一整行
                readonly property bool expanded:
                    Sysmon.psiAvailable && worstPeak >= 1
                readonly property color severity:
                    worstPeak >= 10 ? Color.error : Color.primary

                Layout.fillWidth: true
                // 空闲时收成窄条：三个 0.0 加三条平线不值一整行
                Layout.preferredHeight: (expanded || !Sysmon.psiAvailable) ? 54 : 34
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                radius: Size.rounding.lg
                color: Color.surfaceHigh
                border.width: Style.border.width
                border.color: psiCard.expanded
                    ? Color.withAlpha(psiCard.severity, 0.45)
                    : Color.withAlpha(Color.outlineVariant, Style.border.opacity)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Size.spacing.md
                    anchors.rightMargin: Size.spacing.md
                    spacing: Size.spacing.sm

                    Text {
                        text: Sysmon.psiAvailable ? "PSI" : "Load"
                        color: psiCard.expanded ? psiCard.severity : Color.textMuted
                        font.pixelSize: Size.fontSize.sm
                    }
                    Item { Layout.fillWidth: true }

                    // 空闲态只留一句话——异常时它消失、三栏顶上来，变化本身就是信号
                    Text {
                        visible: Sysmon.psiAvailable && !psiCard.expanded
                        text: "无阻塞"
                        color: Color.withAlpha(Color.textMuted, 0.75)
                        font.pixelSize: Size.fontSize.sm
                    }

                    // 内核没开 PSI 就退回 loadavg
                    Text {
                        visible: !Sysmon.psiAvailable
                        text: Sysmon.load1.toFixed(2)
                        color: Color.text
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                        font.family: Size.fontMono
                    }

                    Repeater {
                        // 收起时 model 置空，三个 Canvas 直接不存在。
                        // 只把它们设成 invisible 的话，数据每到一次仍会走一遍
                        // requestPaint，白烧 CPU。
                        model: psiCard.expanded ? [
                            {
                                label: "CPU", v: Sysmon.psiCpu, c: root.cpuColor,
                                hist: Sysmon.psiCpuHistory, peak: Sysmon.psiCpuPeak
                            },
                            {
                                label: "IO", v: Sysmon.psiIo, c: Color.tertiary,
                                hist: Sysmon.psiIoHistory, peak: Sysmon.psiIoPeak
                            },
                            {
                                label: "内存", v: Sysmon.psiMem, c: root.memColor,
                                hist: Sysmon.psiMemHistory, peak: Sysmon.psiMemPeak
                            }
                        ] : []

                        RowLayout {
                            required property var modelData
                            spacing: 4

                            Text {
                                text: modelData.label
                                color: Color.withAlpha(Color.textMuted, 0.8)
                                font.pixelSize: Size.fontSize.xsm
                            }
                            Sparkline {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                visible: modelData.hist.length > 1
                                values: modelData.hist
                                // 自适应量程：PSI 常年贴 0，固定 0–100 会画成一条死线
                                maxValue: 0
                                minSpan: 5
                                lineColor: modelData.peak >= 10 ? Color.error : modelData.c
                                lineWidth: 1.2
                                cornerRadius: Size.rounding.sm
                                backgroundColor: Color.withAlpha(Color.background, 0.45)
                            }
                            Text {
                                // 超过 10% 说明真的在卡，标红
                                text: modelData.v.toFixed(1)
                                color: modelData.v >= 10 ? Color.error : modelData.c
                                font.pixelSize: Size.fontSize.md
                                font.bold: true
                                font.family: Size.fontMono
                            }
                            Text {
                                // 当前已回落但近期卡过——这才是最该看见的信息
                                visible: modelData.peak >= 1
                                    && modelData.peak > modelData.v + 0.5
                                text: "峰" + modelData.peak.toFixed(1)
                                color: Color.withAlpha(Color.textMuted, 0.75)
                                font.pixelSize: Size.fontSize.xsm
                                font.family: Size.fontMono
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Size.spacing.sm

                InfoCapsule {
                    title: "Swap"
                    value: Sysmon.swapTotalGB > 0.01
                        ? (Sysmon.swapUsedGB.toFixed(1) + "/" + Sysmon.swapTotalGB.toFixed(1))
                        : "—"
                }
                InfoCapsule {
                    title: "Uptime"
                    value: Sysmon.uptimeText
                }
            }
        }

        // 磁盘 / 电池
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            FillCapsule {
                title: "磁盘 /"
                iconName: "hard_drive_2"
                primaryText: Sysmon.diskPercent.toFixed(0) + "%"
                secondaryText: Sysmon.diskUsedGB.toFixed(0) + " / "
                    + Sysmon.diskTotalGB.toFixed(0) + " GB"
                fraction: Sysmon.diskPercent / 100
                accent: Color.tertiary
            }
            FillCapsule {
                show: Battery.isPresent
                title: "电池"
                iconName: Battery.charging ? "battery_charging_full" : "battery_full"
                primaryText: Math.round(Battery.percentage) + "%"
                secondaryText: root.batStatusText()
                    + (Math.abs(Battery.changeRate) > 0.2
                        ? ("  ·  " + Math.abs(Battery.changeRate).toFixed(1) + " W")
                        : "")
                fraction: Battery.percentage / 100
                accent: Battery.percentage < 20 ? Color.error : Color.secondary
            }
        }

        // 下：进程（尽量占满剩余高度，至少约 42%）
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 0
            Layout.minimumHeight: Math.max(240, root.height * 0.42)
            spacing: Size.spacing.sm

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "进程"
                    color: Color.text
                    font.pixelSize: Size.fontSize.md
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [
                        { id: 1, label: "用户" },
                        { id: 0, label: "全部" }
                    ]
                    Rectangle {
                        required property var modelData
                        readonly property bool selected: root.procFilter === modelData.id
                        height: 30
                        width: fl.implicitWidth + 18
                        radius: Size.rounding.full
                        color: selected
                            ? Color.withAlpha(Color.primary, 0.18)
                            : (fMa.containsMouse ? Color.withAlpha(Color.text, 0.06) : "transparent")
                        Text {
                            id: fl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Size.fontSize.sm
                            color: selected ? Color.primary : Color.textMuted
                        }
                        MouseArea {
                            id: fMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.procFilter = modelData.id
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                Text {
                    Layout.fillWidth: true
                    text: "名称"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.sm
                }
                Text {
                    Layout.preferredWidth: 56
                    horizontalAlignment: Text.AlignRight
                    text: "CPU" + (root.sortCol === 0 ? (root.sortAsc ? " ↑" : " ↓") : "")
                    color: root.cpuColor
                    font.pixelSize: Size.fontSize.sm
                    font.bold: root.sortCol === 0
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setSort(0)
                    }
                }
                Text {
                    Layout.preferredWidth: 60
                    horizontalAlignment: Text.AlignRight
                    text: "MEM" + (root.sortCol === 1 ? (root.sortAsc ? " ↑" : " ↓") : "")
                    color: root.memColor
                    font.pixelSize: Size.fontSize.sm
                    font.bold: root.sortCol === 1
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setSort(1)
                    }
                }
                Text {
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignRight
                    text: "PID" + (root.sortCol === 2 ? (root.sortAsc ? " ↑" : " ↓") : "")
                    color: root.pidColor
                    font.pixelSize: Size.fontSize.sm
                    font.bold: root.sortCol === 2
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setSort(2)
                    }
                }
            }

            ListView {
                id: procList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Size.spacing.xs
                reuseItems: true
                model: root.displayProcesses
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    height: 44
                    radius: Size.rounding.md
                    color: rowMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.12)
                        : Color.surface

                    readonly property int pid: Number(modelData.pid) || 0
                    readonly property int uid: (modelData.uid !== undefined) ? Number(modelData.uid) : 1000
                    readonly property real cpu: Number(modelData.cpu_percent) || 0
                    readonly property real memKb: Number(modelData.memory_kb) || 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 6
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || "?"
                            elide: Text.ElideRight
                            color: Color.text
                            font.pixelSize: Size.fontSize.md
                        }
                        Text {
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            text: row.cpu.toFixed(1) + "%"
                            color: row.cpu > 20 ? Color.error : root.cpuColor
                            font.pixelSize: Size.fontSize.sm
                            font.family: Size.fontMono
                            font.bold: true
                        }
                        Text {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: Sysmon.formatMemKB(row.memKb)
                            color: row.memKb > 1048576 ? Color.error : root.memColor
                            font.pixelSize: Size.fontSize.sm
                            font.family: Size.fontMono
                            font.bold: true
                        }
                        Text {
                            Layout.preferredWidth: 48
                            horizontalAlignment: Text.AlignRight
                            text: String(row.pid)
                            color: root.pidColor
                            font.pixelSize: Size.fontSize.sm
                            font.family: Size.fontMono
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (ev) => {
                            if (ev.button === Qt.RightButton) {
                                const p = row.mapToItem(root, ev.x, ev.y)
                                root.openMenu(row.pid, row.uid, p.x, p.y)
                            } else {
                                root.closeMenu()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: procList.count === 0
                    text: Sysmon.daemonOk ? "暂无进程数据" : "等待 sysmond…"
                    color: Color.textMuted
                    font.pixelSize: Size.fontSize.md
                }
            }
        }
    }

    Rectangle {
        id: ctxMenu
        visible: root.menuOpen
        x: Math.min(root.menuX, root.width - width - 8)
        y: Math.min(root.menuY, root.height - height - 8)
        z: 20
        width: 148
        height: menuCol.implicitHeight + 12
        radius: Size.rounding.md
        color: Color.surfaceHighest
        border.width: 1
        border.color: Color.outlineVariant

        Column {
            id: menuCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            Rectangle {
                width: parent.width
                height: 36
                radius: Size.rounding.sm
                color: termMa.containsMouse ? Color.withAlpha(Color.text, 0.08) : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: "结束进程"
                    color: Color.text
                    font.pixelSize: Size.fontSize.md
                }
                MouseArea {
                    id: termMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sysmon.killProcess(root.menuPid, false)
                        root.closeMenu()
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 36
                radius: Size.rounding.sm
                opacity: root.menuUid >= 1000 ? 1 : 0.4
                color: killMa.containsMouse && root.menuUid >= 1000
                    ? Color.withAlpha(Color.error, 0.15)
                    : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    text: "强制结束"
                    color: Color.error
                    font.pixelSize: Size.fontSize.md
                }
                MouseArea {
                    id: killMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.menuUid >= 1000
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sysmon.killProcess(root.menuPid, true)
                        root.closeMenu()
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.menuOpen
        z: 19
        onClicked: root.closeMenu()
    }
}
