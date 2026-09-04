// SysProcsCard — 进程列表（SystemPage 下半拆出的容器卡）
// 筛选/排序/右键菜单（结束进程）原样保留；固定高度，列表内滚动
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 性能：关页停进程轮询由 Leftbar 按页驱动（Sysmon.detailActive）；ListView reuseItems

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    // 头两行（标题+筛选 / 列头）+ 列表区；列表吃剩余高度滚动
    implicitHeight: 420

    property int procFilter: 1
    // 默认按内存从高到低（用户习惯）；点列头切换
    property int sortCol: 1
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

    Component.onCompleted: rebuildProcesses()
    Component.onDestruction: closeMenu()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
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

    Rectangle {
        id: ctxMenu
        visible: root.menuOpen
        x: Math.min(root.menuX, root.width - width - 8)
        y: Math.min(root.menuY, root.height - height - 8)
        z: 20
        width: 148
        height: menuCol.implicitHeight + 12
        radius: Size.rounding.md
        color: Color.surfaceContainerHighest
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
