import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.config

// 单条会话行。柔和 hover（仅前景层 alpha 变化），不再用 1px 边框区分。
// 内联展开：rename / 删除确认。布局上半固定 baseH，下半 anchored 在 topRow.bottom。
Item {
    id: row
    width: ListView.view ? ListView.view.width : implicitWidth

    property var sessionData: ({})
    property bool isActive: false
    property bool isEditing: false
    property bool isConfirmDelete: false

    signal enterRequested(string sid)
    signal editOpenRequested(string sid)
    signal editCancelRequested()
    signal editCommitRequested(string sid, string newTitle)
    signal deleteOpenRequested(string sid)
    signal deleteCancelRequested()
    signal deleteCommitRequested(string sid)

    readonly property string sid: (sessionData && sessionData.id) || ""
    readonly property string title: (sessionData && sessionData.title && sessionData.title.length)
                                    ? sessionData.title : "新对话"
    readonly property bool   archived: sessionData && sessionData.status === "archived"

    readonly property int baseH: 42
    readonly property int extraH: 48
    readonly property bool isExpanded: isEditing || isConfirmDelete

    implicitHeight: baseH + (isExpanded ? extraH : 0)
    Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // 行背景：active 用 secondary_container 弱填，hover 用 on_surface 5% 叠加；不画边框
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Sizes.rounding.medium
        color: row.isActive
            ? Qt.rgba(Colorscheme.secondary_container.r,
                      Colorscheme.secondary_container.g,
                      Colorscheme.secondary_container.b, 0.85)
            : (row.isExpanded
                ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                          Colorscheme.on_surface.b, 0.05)
                : (rowMa.containsMouse
                    ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                              Colorscheme.on_surface.b, 0.04)
                    : "transparent"))
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Item {
        id: topRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: row.baseH

        MouseArea {
            id: rowMa
            anchors.fill: parent
            anchors.rightMargin: 64
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.sid) row.enterRequested(row.sid)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Sizes.spacing.md
            anchors.rightMargin: Sizes.spacing.s
            spacing: Sizes.spacing.s

            // 左侧 active 指示
            Rectangle {
                Layout.preferredWidth: 3
                Layout.preferredHeight: 18
                radius: 2
                color: row.isActive ? Colorscheme.primary : "transparent"
            }

            Text {
                Layout.fillWidth: true
                text: row.title
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.md
                font.weight: row.isActive ? Font.Bold : Font.Medium
                color: row.isActive ? Colorscheme.on_secondary_container
                                    : Colorscheme.on_surface
                elide: Text.ElideRight
            }

            Text {
                visible: row.archived
                text: "inventory_2"
                font.family: Sizes.fontIcon
                font.pixelSize: Sizes.font.sm
                color: Colorscheme.on_surface_variant
            }

            // edit
            Item {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: rnMa.containsMouse
                        ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                                  Colorscheme.on_surface.b, 0.08)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: row.isEditing ? "close" : "edit"
                    font.family: Sizes.fontIcon
                    font.pixelSize: 16
                    color: Colorscheme.on_surface_variant
                }
                MouseArea {
                    id: rnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!row.sid) return;
                        if (row.isEditing) row.editCancelRequested();
                        else row.editOpenRequested(row.sid);
                    }
                }
            }

            // delete
            Item {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: dlMa.containsMouse
                        ? Qt.rgba(Colorscheme.error.r, Colorscheme.error.g,
                                  Colorscheme.error.b, 0.14)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: row.isConfirmDelete ? "close" : "delete"
                    font.family: Sizes.fontIcon
                    font.pixelSize: 16
                    color: dlMa.containsMouse ? Colorscheme.error : Colorscheme.on_surface_variant
                }
                MouseArea {
                    id: dlMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!row.sid) return;
                        if (row.isConfirmDelete) row.deleteCancelRequested();
                        else row.deleteOpenRequested(row.sid);
                    }
                }
            }
        }
    }

    // ---- 展开区 A：rename ----
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topRow.bottom
        height: row.isEditing ? row.extraH : 0
        visible: row.isEditing
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Sizes.spacing.md
            anchors.rightMargin: Sizes.spacing.s
            anchors.bottomMargin: 8
            spacing: 6

            TextField {
                id: titleField
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.sm
                color: Colorscheme.on_surface
                placeholderText: "新标题"
                placeholderTextColor: Colorscheme.outline
                selectByMouse: true
                Material.theme: Material.System
                Material.accent: Colorscheme.primary
                Material.primary: Colorscheme.primary
                Material.foreground: Colorscheme.on_surface
                Material.containerStyle: Material.Outlined
                onAccepted: {
                    var t = text.trim();
                    if (t.length > 0) row.editCommitRequested(row.sid, t);
                }
            }
            Rectangle {
                Layout.preferredWidth: 52; Layout.preferredHeight: 30
                radius: Sizes.rounding.small
                color: okMa.containsMouse
                    ? Colorscheme.primary
                    : Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g,
                              Colorscheme.primary.b, 0.85)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "保存"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_primary
                }
                MouseArea {
                    id: okMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var t = titleField.text.trim();
                        if (t.length > 0) row.editCommitRequested(row.sid, t);
                    }
                }
            }
        }

        onVisibleChanged: if (visible) {
            titleField.text = row.title;
            Qt.callLater(function() { titleField.forceActiveFocus(); titleField.selectAll(); });
        }
    }

    // ---- 展开区 B：删除确认 ----
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topRow.bottom
        height: row.isConfirmDelete ? row.extraH : 0
        visible: row.isConfirmDelete
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Sizes.spacing.md
            anchors.rightMargin: Sizes.spacing.s
            anchors.bottomMargin: 8
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "确认删除？"
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.sm
                color: Colorscheme.on_surface_variant
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 30
                radius: Sizes.rounding.small
                color: cancelMa.containsMouse
                    ? Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                              Colorscheme.on_surface.b, 0.10)
                    : Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g,
                              Colorscheme.on_surface.b, 0.06)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "取消"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_surface
                }
                MouseArea {
                    id: cancelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.deleteCancelRequested()
                }
            }
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 30
                radius: Sizes.rounding.small
                color: delConfirmMa.containsMouse
                    ? Colorscheme.error
                    : Qt.rgba(Colorscheme.error.r, Colorscheme.error.g,
                              Colorscheme.error.b, 0.78)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: "删除"
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.sm
                    color: Colorscheme.on_error
                }
                MouseArea {
                    id: delConfirmMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.deleteCommitRequested(row.sid)
                }
            }
        }
    }
}
