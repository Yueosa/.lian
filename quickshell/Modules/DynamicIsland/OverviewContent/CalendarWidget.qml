import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Clavis.Calendar 1.0
import qs.config 

Rectangle {
    id: root
    color: Colorscheme.surface_container_high 
    radius: Sizes.rounding.xlarge

    function cellBackground(day) {
        if (day.isToday)
            return Colorscheme.primary;
        if (day.isAdjustedWorkday)
            return Qt.rgba(Colorscheme.secondary.r, Colorscheme.secondary.g, Colorscheme.secondary.b, 0.18);
        if (day.isOfficialHoliday)
            return Qt.rgba(Colorscheme.tertiary.r, Colorscheme.tertiary.g, Colorscheme.tertiary.b, 0.18);
        if (day.hasEvent)
            return Qt.rgba(Colorscheme.primary.r, Colorscheme.primary.g, Colorscheme.primary.b, 0.10);
        return "transparent";
    }

    function dayColor(day) {
        if (day.isToday)
            return Colorscheme.on_primary;
        if (!day.isCurrentMonth)
            return Colorscheme.surface_variant;
        if (day.isAdjustedWorkday)
            return Colorscheme.secondary;
        if (day.isOfficialHoliday)
            return Colorscheme.tertiary;
        return Colorscheme.on_surface;
    }

    function labelColor(day) {
        if (!day.isCurrentMonth)
            return Colorscheme.surface_variant;
        if (day.isAdjustedWorkday)
            return Colorscheme.secondary;
        if (day.isOfficialHoliday)
            return Colorscheme.tertiary;
        return Colorscheme.primary;
    }

    function compactLabel(day) {
        if (day.isAdjustedWorkday)
            return "调休";
        if (day.festivalText !== "")
            return day.festivalText.split(" / ")[0];
        return "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: Sizes.spacing.sm
        
        // 1. 顶部：独立药丸控制器
        RowLayout {
            Layout.fillWidth: true
            spacing: Sizes.spacing.m
            
            // 年月显示药丸
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Sizes.rounding.xl
                color: Colorscheme.surface_container_highest
                
                Text {
                    anchors.centerIn: parent
                    text: CalendarPlugin.monthTitle
                    color: Colorscheme.on_surface
                    font.family: Sizes.fontFamily
                    font.pixelSize: Sizes.font.body
                    font.bold: true
                }
            }

            // 翻页按钮组件
            component NavBtn : Rectangle {
                property string iconTxt: ""
                Layout.preferredWidth: 36; Layout.preferredHeight: 32; radius: Sizes.rounding.xl
                color: Colorscheme.surface_container_highest
                scale: ma.pressed ? 0.9 : (ma.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150 } }
                Text { anchors.centerIn: parent; text: iconTxt; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.md; color: Colorscheme.primary }
                signal clicked()
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
            }

            NavBtn { 
                iconTxt: "" // FontAwesome 左箭头
                onClicked: CalendarPlugin.previousMonth()
            }
            NavBtn { 
                iconTxt: "" // FontAwesome 右箭头
                onClicked: CalendarPlugin.nextMonth()
            }
        }
        
        // 2. 星期表头与分割线
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: Sizes.spacing.xxs
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Repeater {
                    model: ["一", "二", "三", "四", "五", "六", "日"]
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 16
                        Text { 
                            anchors.centerIn: parent; text: modelData
                            color: Colorscheme.on_surface_variant; font.family: Sizes.fontFamily; font.pixelSize: Sizes.font.xs; font.bold: true
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colorscheme.surface_container_highest; radius: Sizes.rounding.hairline }
        }
        
        // 3. 日期网格
        GridLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            columns: 7; rowSpacing: 3; columnSpacing: 3
            Repeater {
                model: CalendarPlugin.days
                Item {
                    id: dayCell
                    Layout.fillWidth: true; Layout.fillHeight: true
                    readonly property var day: model
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Sizes.rounding.sm
                        color: root.cellBackground(dayCell.day)
                        border.width: dayCell.day.isToday || dayCell.day.hasEvent ? 1 : 0
                        border.color: dayCell.day.isToday
                            ? Colorscheme.primary
                            : (dayCell.day.isAdjustedWorkday ? Colorscheme.secondary : Colorscheme.outline_variant)

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.compactLabel(dayCell.day) !== "" ? -5 : 0
                        text: dayCell.day.dayNumber
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.lg
                        font.bold: dayCell.day.isToday || dayCell.day.isOfficialHoliday
                        color: root.dayColor(dayCell.day)
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.rightMargin: 2
                        width: 13
                        height: 13
                        radius: Sizes.rounding.full
                        visible: dayCell.day.badgeText !== ""
                        color: dayCell.day.isAdjustedWorkday
                            ? Qt.rgba(Colorscheme.secondary.r, Colorscheme.secondary.g, Colorscheme.secondary.b, 0.28)
                            : Qt.rgba(Colorscheme.tertiary.r, Colorscheme.tertiary.g, Colorscheme.tertiary.b, 0.28)

                        Text {
                            anchors.centerIn: parent
                            text: dayCell.day.badgeText
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.hairline
                            font.bold: true
                            color: dayCell.day.isAdjustedWorkday ? Colorscheme.secondary : Colorscheme.tertiary
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        anchors.bottomMargin: 3
                        text: root.compactLabel(dayCell.day)
                        visible: text !== ""
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.family: Sizes.fontFamily
                        font.pixelSize: Sizes.font.hairline
                        font.bold: dayCell.day.isAdjustedWorkday || dayCell.day.festivalText !== ""
                        color: root.labelColor(dayCell.day)
                    }
                }
            }
        }
    }
}
