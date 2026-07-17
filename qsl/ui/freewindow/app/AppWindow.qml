// AppWindow — 应用启动器（Super+A）
// 左 60% 壁纸预览 + 右 40% AppPage；无 Tab / 无按键提示 / 无左下角文案

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data.state
import qs.ui.freewindow

FreeWindow {
    id: root

    shellNamespace: "qsl-app"

    onOpenChanged: {
        if (open)
            Qt.callLater(function() { appPage.reset() })
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: "transparent"
        radius: Size.rounding.xl
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // 左 60% — 壁纸预览（不叠文案）
            Item {
                Layout.preferredWidth: Math.round(parent.width * 0.6)
                Layout.maximumWidth: Math.round(parent.width * 0.6)
                Layout.fillHeight: true

                Rectangle {
                    id: previewPaneBg
                    anchors.fill: parent
                    color: Color.surfaceHigh
                    topLeftRadius: Size.rounding.xl
                    bottomLeftRadius: Size.rounding.xl

                    Image {
                        id: wallpaperImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        // Wallpaper.preview 已含真实路径 + ?v=，路径一变必重载
                        source: Wallpaper.preview
                        asynchronous: true
                        // Item 常驻即可预热；禁用全局缓存，避免换壁纸后旧 ?v= 条目累积
                        cache: false
                        smooth: true
                        sourceSize.width: Math.max(1, Math.round(previewPaneBg.width))
                        sourceSize.height: Math.max(1, Math.round(previewPaneBg.height))

                        onStatusChanged: {
                            if (status === Image.Error && source.indexOf("current_preview") >= 0)
                                source = Wallpaper.current
                        }
                    }

                    // 轻遮罩，只为层次，不再服务文字可读性
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Color.withAlpha(Color.shadow, 0.04) }
                            GradientStop { position: 1.0; color: Color.withAlpha(Color.shadow, 0.16) }
                        }
                    }
                }
            }

            // 右 40% — 列表
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                Rectangle {
                    anchors.fill: parent
                    color: Color.withAlpha(Color.surfaceHigh, 0.9)
                    topRightRadius: Size.rounding.xl
                    bottomRightRadius: Size.rounding.xl
                    clip: true

                    AppPage {
                        id: appPage
                        anchors.fill: parent
                        anchors.margins: 24
                        onLaunchRequested: root.closeWindow()
                        onCloseRequested: root.closeWindow()
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Color.secondaryFixed
            border.width: 2
            radius: Size.rounding.xl
        }
    }
}
