// AppWindow — 应用启动器
//     Super+A → qs ipc call free-window-app toggle
//     Esc → 向上滑出 / Enter 启动 → 渐变消失

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.data.state
import qs.ui.freewindow

FreeWindow {
    id: root

    WlrLayershell.namespace: "qsl-app"

    readonly property string wallpaperSource:
        "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"

    // ============================================================
    // 6:4 布局
    // ============================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左 40% — 当前壁纸
        Rectangle {
            Layout.preferredWidth: Math.round(parent.width * 0.4)
            Layout.fillHeight: true
            color: Color.surfaceHigh

            Image {
                anchors.fill: parent
                source: root.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: 640
                sourceSize.height: 480
            }

            // 渐变遮罩
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.05) }
                    GradientStop { position: 0.5; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.15) }
                    GradientStop { position: 1.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.40) }
                }
            }
        }

        // 右 60% — 应用列表
        AppPage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onLaunchRequested: root.quickClose()
            onCloseRequested:  root.closeWindow()
        }
    }
}
