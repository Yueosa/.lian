import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.ActiveWindow
import qs.Modules.Bar.Tray
import qs.Modules.Bar.QuickSettings
import qs.Components
import qs.config

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData

        anchors { left: true; top: true; right: true }
        color: "transparent"
        
        property real barHeight: 46
        property real shadowBleed: 10  // 阴影向下溢出的安全边距
        
        // 窗口高度包含阴影溢出量，exclusiveZone 只占实际 bar 高度
        implicitHeight: barHeight + shadowBleed
        
        exclusiveZone: barHeight
        
        WlrLayershell.layer: WidgetState.shouldOverlayPersistent() ? WlrLayer.Overlay : WlrLayer.Top

        LayerSurfaceRemapper {
            window: barWindow
            active: WidgetState.shouldOverlayPersistent()
        }

        // --- 内容容器 ---
        Item {
            id: barContent
            
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: barWindow.barHeight 

            // --- 左侧组件 ---
            RowLayout {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: Sizes.spacing.m

                Workspaces { screenName: barWindow.screen.name }
                ActiveWindow {}
                
            }

            // --- 右侧组件 ---
            RowLayout {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: Sizes.spacing.m

                Tray {}

                QuickSettings { Layout.alignment: Qt.AlignVCenter }
                
                
            }
        }
    }
}
