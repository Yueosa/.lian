import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell
import qs.config
import qs.Services

Item {
    id: root
    signal closeRequested() 

    implicitWidth: Sizes.island.overviewWidth
    implicitHeight: Sizes.island.overviewHeight 

    property int activeSliderIndex: 0 

    // ============================================================
    // 【极简亚克力卡片组件】
    // ============================================================
    component SolidGlassCard : Item {
        id: cardRoot
        default property alias content: innerContainer.data
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Sizes.island.ccHoleRadius
            // 挤压玻璃：靶点下露出壁纸，才很调色板随动
            color: Qt.rgba(
                Colorscheme.surface_container_lowest.r,
                Colorscheme.surface_container_lowest.g,
                Colorscheme.surface_container_lowest.b,
                Sizes.island.glassCardAlpha
            )
            border.width: 1
            border.color: Qt.rgba(
                Colorscheme.outline_variant.r,
                Colorscheme.outline_variant.g,
                Colorscheme.outline_variant.b,
                Sizes.island.glassCardBorderAlpha
            )
        }
        Item { id: innerContainer; anchors.fill: parent; anchors.margins: 16 }
    }

    component ExpandableVertSlider : Item {
        id: sliderCol
        property int sliderIndex: 0 
        property string icon: ""
        property real sliderValue: 0.5
        property bool expanded: false
        signal sliderMoved(real val)

        property real expandProgress: expanded ? 1.0 : 0.0
        Behavior on expandProgress { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        width: 48
        implicitHeight: 48 + (128 * expandProgress)

        Rectangle {
            width: 48; height: 48; radius: Sizes.rounding.xlarge
            color: sliderCol.expanded ? Colorscheme.primary : Colorscheme.surface_container_highest
            Behavior on color { ColorAnimation { duration: 250 } }
            Text {
                anchors.centerIn: parent; text: sliderCol.icon; font.family: Sizes.fontAwesome; font.pixelSize: Sizes.font.xxl
                color: sliderCol.expanded ? Colorscheme.on_primary : Colorscheme.on_surface
            }
            MouseArea { 
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                onClicked: root.activeSliderIndex = (root.activeSliderIndex === sliderCol.sliderIndex ? -1 : sliderCol.sliderIndex) 
            }
        }

        Item {
            y: 48 + (8 * sliderCol.expandProgress)
            width: 48; height: 120 * sliderCol.expandProgress; opacity: sliderCol.expandProgress
            
            Item {
                anchors.centerIn: parent; width: 16; height: parent.height - 4; clip: true
                Rectangle {
                    anchors.fill: parent; radius: Sizes.rounding.small; color: Colorscheme.surface_container_lowest
                    Rectangle {
                        x: parent.width / 2 - width / 2; y: 4; width: 4; height: parent.height - 8; radius: Sizes.rounding.xxs; color: Colorscheme.surface_container_highest
                        Rectangle {
                            width: parent.width; height: (1.0 - vSlider.visualPosition) * parent.height; y: vSlider.visualPosition * parent.height
                            radius: Sizes.rounding.xxs; color: Colorscheme.primary
                        }
                    }
                }
            }

            Slider {
                id: vSlider
                orientation: Qt.Vertical; anchors.fill: parent; anchors.margins: 4
                value: sliderCol.sliderValue; hoverEnabled: true; background: Item {} 
                onMoved: sliderCol.sliderMoved(value)

                handle: Rectangle {
                    x: vSlider.leftPadding + vSlider.availableWidth / 2 - width / 2
                    y: vSlider.topPadding + vSlider.visualPosition * (vSlider.availableHeight - height)
                    width: 12; height: 12; radius: Sizes.rounding.sm; color: Colorscheme.primary
                    Item {
                        anchors.left: parent.right; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36; visible: vSlider.pressed || vSlider.hovered; opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Rectangle { anchors.fill: parent; radius: Sizes.rounding.xl; color: Colorscheme.primary_container }
                        Rectangle { 
                            width: 12; height: 12; radius: Sizes.rounding.xxs; color: Colorscheme.primary_container; rotation: 45
                            anchors.left: parent.left; anchors.leftMargin: -4; anchors.verticalCenter: parent.verticalCenter; z: -1
                        }
                        Text { 
                            anchors.centerIn: parent; text: Math.round(vSlider.value * 100); color: Colorscheme.on_primary_container
                            font.pixelSize: Sizes.font.lg; font.bold: true; font.family: Sizes.fontFamilyMono 
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Sizes.island.overviewMargin
        spacing: Sizes.island.overviewSpacing

        // 第一列：滑块
        ColumnLayout {
            z: 100; Layout.preferredWidth: Sizes.island.overviewSliderColW; Layout.fillHeight: true; Layout.alignment: Qt.AlignTop; spacing: Sizes.spacing.md
            ExpandableVertSlider { sliderIndex: 0; icon: ""; expanded: root.activeSliderIndex === 0; sliderValue: Volume.sinkVolume; onSliderMoved: (val) => Volume.setSinkVolume(val) } 
            ExpandableVertSlider { sliderIndex: 1; icon: ""; expanded: root.activeSliderIndex === 1; sliderValue: Volume.sourceVolume; onSliderMoved: (val) => Volume.setSourceVolume(val) }
            Item { Layout.fillHeight: true } 
        }

        // 第二列：系统信息与日历
        ColumnLayout {
            Layout.preferredWidth: Sizes.island.overviewSysColW; Layout.maximumWidth: Sizes.island.overviewSysColW; Layout.minimumWidth: Sizes.island.overviewSysColW; Layout.fillHeight: true; spacing: Sizes.spacing.xl
            SysInfoWidget { Layout.fillWidth: true; Layout.preferredHeight: 115 }
            CalendarWidget { Layout.fillWidth: true; Layout.fillHeight: true }
        }

        // 第三列：控制中心
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                radius: Sizes.island.ccHoleRadius
                color: Colorscheme.surface_container_high
                ControlCenterWidget { anchors.fill: parent; anchors.margins: 16 }
            }
        }
    }
}
