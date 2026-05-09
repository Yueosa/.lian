import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.config 

// 新增引入我们的 C++ 高性能监控库
import Clavis.Sysmon 1.0

Item {
    id: root

    property bool isHovered: mouseArea.containsMouse
    
    implicitHeight: 36
    
    implicitWidth: {
        if (isHovered) {
            return contentLayout.implicitWidth + 24;
        }
        return ramGroup.implicitWidth + 24;
    }

    Behavior on implicitWidth { 
        NumberAnimation { duration: 300; easing.type: Easing.OutQuart } 
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: Colorscheme.background
        radius: height / 2 
        visible: false 
    }



    MultiEffect {
        source: bgRect
        anchors.fill: bgRect
        shadowEnabled: true
        shadowColor: Qt.alpha(Colorscheme.shadow, 0.4)
        shadowBlur: 0.8
        shadowVerticalOffset: 3
    }

    // （这里原本庞大的 Process 启动子线程和 SplitParser JSON 提取，以及循环调度的 Timer 已被彻底抹去）

    // ================= 布局内容 =================
    RowLayout {
        id: contentLayout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 12
        spacing: Sizes.spacing.md
        layoutDirection: Qt.RightToLeft

        // --- 1. RAM (常驻) ---
        RowLayout {
            id: ramGroup
            spacing: Sizes.spacing.xs
            Text { 
                text: "" 
                color: Colorscheme.secondary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
            Text { 
                // 同时保全了原始流的传递。并在这里调取新的 ramUsedGB。toFixed(1) 可保留如 14.2G 格式：
                text: SysmonPlugin.ramUsedGB.toFixed(1) + "G"
                color: Colorscheme.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
        }

        // --- 2. Disk (展开) ---
        RowLayout {
            id: diskGroup
            spacing: Sizes.spacing.xs
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Colorscheme.primary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
            Text { 
                text: Math.round(SysmonPlugin.diskUsage) + "%"
                color: Colorscheme.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
        }

        // --- 3. Temp (展开) ---
        RowLayout {
            id: tempGroup
            spacing: Sizes.spacing.xs
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Colorscheme.secondary_container
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
            Text { 
                text: Math.round(SysmonPlugin.coreTemp) + "°C"
                color: Colorscheme.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
        }

        // --- 4. CPU (展开) ---
        RowLayout {
            id: cpuGroup
            spacing: Sizes.spacing.xs
            visible: opacity > 0
            opacity: root.isHovered ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            Text { 
                text: "" 
                color: Colorscheme.tertiary
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
            Text { 
                text: Math.round(SysmonPlugin.cpuUsage) + "%"
                color: Colorscheme.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Sizes.font.md
            }
        }
    }

    // ================= 交互区域 =================
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true 
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            Quickshell.execDetached(["gnome-system-monitor"]);
        }
    }
}
