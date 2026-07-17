// SystemPage — 轻量系统页
// 大胶囊进度（CPU/GPU/MEM/磁盘/电池）+ 2×2 信息卡 + 胶囊进程行
// 无 Canvas / 无曲线；进页 Sysmon.detailActive；齿轮 → kitty htop
//
// 性能：关页停进程轮询；ListView reuseItems + Layout.fillHeight；无展开 smaps

import QtQuick
import QtQuick.Layouts
import Quickshell
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

        visible: show
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Size.rounding.lg
        color: Color.surface
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
        color: Color.surface

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
                color: htopMa.containsMouse
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
                    id: htopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sysmon.openHtop()
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
            }
        }

        // 中：Swap / Net / Load / Uptime — 2×2
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Size.spacing.sm
            columnSpacing: Size.spacing.sm

            InfoCapsule {
                title: "Swap"
                value: Sysmon.swapTotalGB > 0.01
                    ? (Sysmon.swapUsedGB.toFixed(1) + "/" + Sysmon.swapTotalGB.toFixed(1))
                    : "—"
            }
            InfoCapsule {
                // 只显示较快的一侧，避免两行速率挤成 …
                title: "网络"
                value: {
                    const down = Sysmon.netDownBps
                    const up = Sysmon.netUpBps
                    if (up > down)
                        return "↑ " + Sysmon.formatBytes(up)
                    return "↓ " + Sysmon.formatBytes(down)
                }
            }
            InfoCapsule {
                title: "Load"
                value: Sysmon.load1.toFixed(2)
            }
            InfoCapsule {
                title: "Uptime"
                value: Sysmon.uptimeText
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
