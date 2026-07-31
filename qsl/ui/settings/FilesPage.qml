// FilesPage — 本地配置文件（键位 + 节假日等）
// 摘要卡 + kitty -e nvim 打开；不内嵌大表/全量列表
// 性能：无 Timer；Hotkeys.groups 只读长度；关页销毁

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.data.service

Item {
    id: root

    readonly property int year: (new Date()).getFullYear()
    readonly property string hotkeysPath: Hotkeys.jsonPath
        || (Quickshell.shellDir + "/asset/hotkeys.json")
    readonly property string calDir: Quickshell.shellDir + "/asset/calendar"
    readonly property string yearFile: calDir + "/" + year + ".json"
    readonly property string todoPath: {
        const home = Quickshell.env("HOME") || ""
        return home + "/.local/share/qsl/todo.json"
    }
    readonly property string lockPamPath: Quickshell.shellDir + "/ui/lock/pam/password.conf"

    readonly property int hotkeyGroupCount: {
        void Hotkeys.groups
        const gs = Hotkeys.groups || []
        return gs.length
    }

    readonly property int hotkeyItemCount: {
        void Hotkeys.groups
        void Hotkeys.ready
        let n = 0
        const gs = Hotkeys.groups || []
        for (let i = 0; i < gs.length; i++) {
            const g = gs[i]
            if (!g)
                continue
            const rows = Hotkeys.flatRowsOf(g.id) || []
            for (let j = 0; j < rows.length; j++) {
                if (rows[j] && rows[j].kind === "item")
                    n++
            }
        }
        return n
    }

    function editInNvim(path) {
        if (!path)
            return
        Quickshell.execDetached(["kitty", "-e", "nvim", path])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.md

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "本地文件"
                font.bold: true
                font.pixelSize: Size.fontSize.hero
                color: Color.textOnBackground
            }
            Text {
                Layout.fillWidth: true
                text: "用 kitty + nvim 编辑配置。改完后部分项需 reload Hyprland / 重启 qs。"
                wrapMode: Text.WordWrap
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
            }
        }

        // 键位摘要
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Size.rounding.md
            color: Color.withAlpha(Color.primary, 0.12)
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.md

                Text {
                    text: "keyboard"
                    font.family: Size.fontIcon
                    font.pixelSize: 32
                    color: Color.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "快捷键 · hotkeys.json"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.primary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Hotkeys.error
                            ? Hotkeys.error
                            : (Hotkeys.ready
                                ? (root.hotkeyGroupCount + " 组 · " + root.hotkeyItemCount + " 条")
                                : "读取中…")
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hotkeysPath
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.preferredWidth: hkBtn.implicitWidth + 28
                    Layout.preferredHeight: 36
                    radius: height / 2
                    color: hkMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.28)
                        : Color.withAlpha(Color.primary, 0.18)
                    Text {
                        id: hkBtn
                        anchors.centerIn: parent
                        text: "nvim 打开"
                        font.bold: true
                        font.pixelSize: Size.fontSize.sm
                        color: Color.primary
                    }
                    MouseArea {
                        id: hkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editInNvim(root.hotkeysPath)
                    }
                }
            }
        }

        // 节假日摘要
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Size.rounding.md
            color: Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.md

                Text {
                    text: "calendar_month"
                    font.family: Size.fontIcon
                    font.pixelSize: 32
                    color: Color.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: year + " 年节假日"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "asset/calendar/<year>.json · Island / 侧栏日历共用"
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.yearFile
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.preferredWidth: calBtn.implicitWidth + 28
                    Layout.preferredHeight: 36
                    radius: height / 2
                    color: calMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.28)
                        : Color.withAlpha(Color.primary, 0.18)
                    Text {
                        id: calBtn
                        anchors.centerIn: parent
                        text: "nvim 打开"
                        font.bold: true
                        font.pixelSize: Size.fontSize.sm
                        color: Color.primary
                    }
                    MouseArea {
                        id: calMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editInNvim(root.yearFile)
                    }
                }
            }
        }

        // 待办
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Size.rounding.md
            color: Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.md

                Text {
                    text: "checklist"
                    font.family: Size.fontIcon
                    font.pixelSize: 32
                    color: Color.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "待办 · todo.json"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Todo.count + " 条 · 已完成 " + Todo.doneCount
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.todoPath
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.preferredWidth: todoBtn.implicitWidth + 28
                    Layout.preferredHeight: 36
                    radius: height / 2
                    color: todoMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.28)
                        : Color.withAlpha(Color.primary, 0.18)
                    Text {
                        id: todoBtn
                        anchors.centerIn: parent
                        text: "nvim 打开"
                        font.bold: true
                        font.pixelSize: Size.fontSize.sm
                        color: Color.primary
                    }
                    MouseArea {
                        id: todoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editInNvim(root.todoPath)
                    }
                }
            }
        }

        // 锁屏 PAM
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Size.rounding.md
            color: Color.surfaceHigh
            border.width: Style.border.width
            border.color: Color.withAlpha(Color.outlineVariant, Style.border.opacity)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.md

                Text {
                    text: "lock"
                    font.family: Size.fontIcon
                    font.pixelSize: 32
                    color: Color.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "锁屏 PAM · password.conf"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "qsl SessionLock 鉴权；改后需重启 qs"
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.lockPamPath
                        font.pixelSize: Size.fontSize.xsm
                        color: Color.textMuted
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    Layout.preferredWidth: pamBtn.implicitWidth + 28
                    Layout.preferredHeight: 36
                    radius: height / 2
                    color: pamMa.containsMouse
                        ? Color.withAlpha(Color.primary, 0.28)
                        : Color.withAlpha(Color.primary, 0.18)
                    Text {
                        id: pamBtn
                        anchors.centerIn: parent
                        text: "nvim 打开"
                        font.bold: true
                        font.pixelSize: Size.fontSize.sm
                        color: Color.primary
                    }
                    MouseArea {
                        id: pamMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editInNvim(root.lockPamPath)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
