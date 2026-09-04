// AppWindow — 应用启动器（Super+A）
// 左 60% 壁纸预览 + 右 40% AppPage；无 Tab / 无按键提示 / 无左下角文案
//
// 圆角：右侧实心 Rectangle 自带半径即可；左侧 Image 必须 OpacityMask
//（Item.clip / 父级 radius 都裁不住 Image）。Ready 即开 layer（常驻，
// 避免 IPC 开窗瞬间建 FBO 卡顿）。Image.cache 保解码。

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
                    color: Color.surfaceContainerHigh
                    topLeftRadius: Size.rounding.xxl
                    bottomLeftRadius: Size.rounding.xxl

                    Item {
                        id: wallpaperClip
                        anchors.fill: parent
                        // Ready 即开 OpacityMask；勿跟 contentActive 绑——开窗瞬间建 FBO 会卡 IPC
                        layer.enabled: wallpaperImage.status === Image.Ready
                        layer.smooth: true
                        layer.effect: OpacityMask {
                            maskSource: Item {
                                width: wallpaperClip.width
                                height: wallpaperClip.height
                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: Size.rounding.xxl
                                    bottomLeftRadius: Size.rounding.xxl
                                    color: "#000000"
                                }
                            }
                        }

                        Image {
                            id: wallpaperImage
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: Wallpaper.preview
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: Math.max(1, Math.round(previewPaneBg.width))
                            sourceSize.height: Math.max(1, Math.round(previewPaneBg.height))

                            onStatusChanged: {
                                if (status === Image.Error && source.indexOf("current_preview") >= 0)
                                    source = Wallpaper.current
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Color.withAlpha(Color.shadow, 0.04) }
                                GradientStop { position: 1.0; color: Color.withAlpha(Color.shadow, 0.16) }
                            }
                        }
                    }
                }
            }

            // 右 40% — 列表（实心底，半径自裁）
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                Rectangle {
                    anchors.fill: parent
                    color: Color.background
                    topRightRadius: Size.rounding.xxl
                    bottomRightRadius: Size.rounding.xxl

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
            radius: Size.rounding.xxl
        }
    }
}
