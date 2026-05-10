import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import Clavis.LianClaw
import qs.config

// 顶部"当前会话"卡片 + 可展开的会话列表 + 底部 footer。
// 风格对齐 WeatherInsightCard：大圆角、半透明 surface_container_high、柔和 outline_variant 边框。
Item {
    id: root

    property int headerH: 56
    property int rowH: 42 + 4   // SessionRow.baseH + 上下 margin 2
    property int extraH: 48     // SessionRow 展开增量
    property int footerCollapsedH: 44
    property int footerEditH: 100
    property int maxListVisible: 8

    property bool expanded: false

    property string _editSid: ""
    property string _delSid: ""
    property bool   _newOpen: false

    readonly property int extraExpansion:
        ((_editSid !== "" || _delSid !== "") ? extraH : 0)

    readonly property int rowsCount: Math.max(1, LianClawState.sessions.length)
    readonly property int listH: Math.min(rowsCount, maxListVisible) * rowH + extraExpansion

    readonly property int footerH: _newOpen ? footerEditH : footerCollapsedH
    readonly property int panelInner: 8   // 与 panel 的 margins 配合
    readonly property int panelH: listH + footerH + panelInner * 2

    implicitHeight: headerH + (expanded ? (panelH + 6) : 0)
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    function _statsLine() {
        var meta = LianClawState.currentMeta || {};
        var parts = [];
        var n = LianClawState.blocks ? LianClawState.blocks.count : 0;
        if (n > 0) parts.push(n + " 条消息");
        if (LianClawState.currentModeChoice) parts.push(LianClawState.currentModeChoice);
        if (LianClawState.currentWorkMode)   parts.push(LianClawState.currentWorkMode);
        if (LianClawState.currentIsArchived) parts.push("已归档");
        return parts.join("  ·  ");
    }

    // ---------------- Header ----------------
    LcSurfaceCard {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerH
        cardRadius: Sizes.rounding.xl
        cardOpacity: hMa.containsMouse ? 1.0 : 0.93
        Behavior on cardOpacity { NumberAnimation { duration: 160 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Sizes.spacing.lg
            anchors.rightMargin: Sizes.spacing.md
            spacing: Sizes.spacing.m

            // 在线指示
            Rectangle {
                Layout.preferredWidth: 8; Layout.preferredHeight: 8
                radius: 4
                color: LianClawClient.serverReady ? Colorscheme.primary : Colorscheme.error
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (LianClawState.currentSid) {
                            var t = LianClawState.currentMeta && LianClawState.currentMeta.title;
                            return (t && t.length) ? t : "新对话";
                        }
                        return "LianClaw";
                    }
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.body
                    font.bold: true
                    color: Colorscheme.on_surface
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (!LianClawState.currentSid)
                            return LianClawClient.serverReady
                                ? (LianClawState.sessions.length + " 个会话 · 点此选择")
                                : "未连接 LianClaw 服务";
                        var s = root._statsLine();
                        return s.length > 0 ? s : "点击展开会话列表";
                    }
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.xs
                    color: Colorscheme.on_surface_variant
                    elide: Text.ElideRight
                }
            }

            Text {
                text: root.expanded ? "expand_less" : "expand_more"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 22
                color: Colorscheme.on_surface_variant
            }
        }

        MouseArea {
            id: hMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.expanded) LianClawState.refreshSessions();
                root.expanded = !root.expanded;
                if (!root.expanded) {
                    root._editSid = "";
                    root._delSid = "";
                    root._newOpen = false;
                }
            }
        }
    }

    // ---------------- Panel：列表 + footer ----------------
    LcSurfaceCard {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: 6
        height: root.expanded ? root.panelH : 0
        clip: true
        opacity: root.expanded ? 1.0 : 0.0
        visible: height > 0
        cardRadius: Sizes.rounding.xl
        cardOpacity: 0.86
        Behavior on height  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // 列表
        ListView {
            id: lv
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: root.panelInner
            anchors.leftMargin: root.panelInner - 2
            anchors.rightMargin: root.panelInner - 2
            height: root.listH
            clip: true
            model: LianClawState.sessions
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: LcThinScrollBar {}

            delegate: SessionRow {
                sessionData: modelData
                isActive: modelData && modelData.id === LianClawState.currentSid
                isEditing: modelData && modelData.id === root._editSid
                isConfirmDelete: modelData && modelData.id === root._delSid

                onEnterRequested:        function(sid) { LianClawState.enterSession(sid); root.expanded = false; }
                onEditOpenRequested:     function(sid) { root._delSid = ""; root._newOpen = false; root._editSid = sid; }
                onEditCancelRequested:                  { root._editSid = ""; }
                onEditCommitRequested:   function(sid, t) { LianClawState.renameSession(sid, t); root._editSid = ""; }
                onDeleteOpenRequested:   function(sid) { root._editSid = ""; root._newOpen = false; root._delSid = sid; }
                onDeleteCancelRequested:                { root._delSid = ""; }
                onDeleteCommitRequested: function(sid) { LianClawState.deleteSession(sid); root._delSid = ""; }
            }

            Text {
                anchors.centerIn: parent
                visible: lv.count === 0 && !LianClawState.sessionsLoading
                text: LianClawState.sessionsError !== "" ? LianClawState.sessionsError : "没有会话，点击下方新建"
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.sm
                color: Colorscheme.on_surface_variant
            }
        }

        // footer 容器
        Item {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.panelInner
            anchors.rightMargin: root.panelInner
            anchors.bottomMargin: root.panelInner
            height: root.footerH
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // collapsed: 新建 + 刷新
            RowLayout {
                anchors.fill: parent
                spacing: 6
                visible: !root._newOpen

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Sizes.rounding.medium
                    color: newMa.containsMouse
                        ? Colorscheme.primary
                        : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g,
                                  Colorscheme.primary.b, 0.78)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "add"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            color: Colorscheme.on_primary
                        }
                        Text {
                            text: "新建会话"
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            font.bold: true
                            color: Colorscheme.on_primary
                        }
                    }
                    MouseArea {
                        id: newMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root._editSid = "";
                            root._delSid = "";
                            root._newOpen = true;
                            Qt.callLater(function() { newField.forceActiveFocus(); });
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.fillHeight: true
                    radius: Sizes.rounding.medium
                    color: rfMa.containsMouse
                        ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                  Colorscheme.on_surface.b, 0.10)
                        : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                  Colorscheme.on_surface.b, 0.05)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: "Material Symbols Outlined"
                        font.pixelSize: 18
                        color: Colorscheme.on_surface_variant
                    }
                    MouseArea {
                        id: rfMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LianClawState.refreshSessions()
                    }
                }
            }

            // expanded: TextField + 取消/创建
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: root._newOpen

                TextField {
                    id: newField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    placeholderText: "新会话标题（留空使用『新对话』）"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface
                    placeholderTextColor: Colorscheme.outline
                    selectByMouse: true
                    Material.theme: Material.System
                    Material.accent: Colorscheme.primary
                    Material.primary: Colorscheme.primary
                    Material.foreground: Colorscheme.on_surface
                    Material.containerStyle: Material.Outlined
                    onAccepted: {
                        LianClawState.createSession(text.trim());
                        text = "";
                        root._newOpen = false;
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredWidth: 56; Layout.preferredHeight: 32
                        radius: Sizes.rounding.medium
                        color: cancelNewMa.containsMouse
                            ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                      Colorscheme.on_surface.b, 0.10)
                            : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                      Colorscheme.on_surface.b, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            color: Colorscheme.on_surface
                        }
                        MouseArea {
                            id: cancelNewMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { newField.text = ""; root._newOpen = false; }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 56; Layout.preferredHeight: 32
                        radius: Sizes.rounding.medium
                        color: createNewMa.containsMouse
                            ? Colorscheme.primary
                            : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g,
                                      Colorscheme.primary.b, 0.85)
                        Text {
                            anchors.centerIn: parent
                            text: "创建"
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            font.bold: true
                            color: Colorscheme.on_primary
                        }
                        MouseArea {
                            id: createNewMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LianClawState.createSession(newField.text.trim());
                                newField.text = "";
                                root._newOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
