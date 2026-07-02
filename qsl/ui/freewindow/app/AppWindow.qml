// AppWindow — 应用启动器（Super+A）

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.ui.freewindow

FreeWindow {
    id: root

    WlrLayershell.namespace: "qsl-app"

    onOpenChanged: {
        if (open) Qt.callLater(function() {
            if (appPage.searchInput) appPage.searchInput.takeFocus()
        })
    }

    readonly property string wallpaperSource:
        "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"

    // ============================================================
    // 6:4 布局（壁纸 60% : 内容 40%）
    // ============================================================

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // 左 60% — 壁纸预览
        Rectangle {
            id: leftPane
            Layout.preferredWidth: Math.round(parent.width * 0.6)
            Layout.fillHeight: true
            color: Color.surfaceHigh

            Image {
                anchors.fill: parent
                source: root.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: false
                sourceSize.width: 640; sourceSize.height: 480
            }

            // 渐变遮罩
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.08) }
                    GradientStop { position: 0.45; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.18) }
                    GradientStop { position: 1.0; color: Qt.rgba(Color.shadow.r, Color.shadow.g, Color.shadow.b, 0.48) }
                }
            }
        }

        // 右 40% — 应用列表
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Qt.rgba(Color.surfaceHigh.r, Color.surfaceHigh.g, Color.surfaceHigh.b, 0.9)

            AppPage {
                id: appPage
                anchors.fill: parent
                anchors.margins: 20
                onLaunchRequested: root.closeWindow()
                onCloseRequested:  root.closeWindow()
            }
        }
    }
}
