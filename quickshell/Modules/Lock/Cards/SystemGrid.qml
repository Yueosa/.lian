import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import Clavis.Sysmon 1.0

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 280

    color: Colorscheme.surface_container
    radius: Sizes.lockCardRadius

    // 直接绑定 SysmonPlugin (1s/2s/30s 自驱动), 替代旧的 python3 sys_monitor.py 每 2s fork

    // ================== 网格布局 ==================
    GridLayout {
        anchors.fill: parent
        anchors.margins: Sizes.lockCardPadding
        columns: 2
        rowSpacing: 15
        columnSpacing: 15

        // 1. CPU (紫色)
        SystemCircle { 
            title: "CPU"
            icon: "" // Nerd Font Chip
            value: SysmonPlugin.cpuUsage / 100
            display: Math.round(SysmonPlugin.cpuUsage) + "%"
            accent: Colorscheme.tertiary
        }

        // 2. Temp (红/橙色)
        SystemCircle { 
            title: "TEMP"
            icon: "" // Thermometer
            value: Math.min(Math.max(SysmonPlugin.coreTemp, 0), 100) / 100
            display: Math.round(SysmonPlugin.coreTemp) + "°C"
            accent: Colorscheme.error
        }

        // 3. RAM (蓝色)
        SystemCircle { 
            title: "RAM"
            icon: "\ue266" // Memory
            value: SysmonPlugin.ramUsage / 100
            display: SysmonPlugin.ramUsedGB.toFixed(1) + "G"
            accent: Colorscheme.primary
        }

        // 4. Disk (青/黄色)
        SystemCircle { 
            title: "DISK"
            icon: "" // HDD
            value: SysmonPlugin.diskUsage / 100
            display: Math.round(SysmonPlugin.diskUsage) + "%"
            accent: Colorscheme.secondary
        }
    }

    // ================== 圆形组件封装 ==================
    component SystemCircle: Item {
        property string title
        property string icon
        property real value: 0.0
        property string display: ""
        property color accent
        
        Layout.fillWidth: true
        Layout.fillHeight: true
        
        // 每个格子的背景
        Rectangle {
            anchors.fill: parent
            color: Colorscheme.surface_container_highest
            radius: Sizes.rounding.large
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            // 进度环容器
            Item {
                width: 60; height: 60
                Layout.alignment: Qt.AlignHCenter
                
                // 旋转 -90 度，让进度从顶部开始
                Shape {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    rotation: -90
                    
                    // 1. 底部轨道 (暗色)
                    ShapePath {
                        strokeColor: Qt.rgba(Colorscheme.on_surface.r, Colorscheme.on_surface.g, Colorscheme.on_surface.b, 0.1)
                        strokeWidth: 6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 30; centerY: 30; radiusX: 27; radiusY: 27; startAngle: 0; sweepAngle: 360 }
                    }
                    
                    // 2. 进度条 (亮色)
                    ShapePath {
                        strokeColor: accent
                        strokeWidth: 6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { 
                            centerX: 30; centerY: 30; radiusX: 27; radiusY: 27; 
                            startAngle: 0; 
                            // 确保 value 不为 undefined 且在 0-1 之间
                            sweepAngle: 360 * (Math.min(Math.max(value, 0), 1))
                        }
                    }
                }
                
                // 中间的图标
                Text {
                    anchors.centerIn: parent
                    text: icon
                    color: accent
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: 22
                }
            }
            
            // 底部文字 (标题 + 数值)
            Text {
                text: display
                color: Colorscheme.on_surface
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.sm
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
