import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import Clavis.Notif 

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    
    color: Colorscheme.surface_container
    radius: Sizes.lockCardRadius
    clip: true

    // ================== 界面布局 ==================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10

        // 标题栏
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text {
                text: "Notifications"
                color: Colorscheme.on_surface_variant
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.sm
                font.bold: true
            }
            
            // 计数器
            Rectangle {
                visible: NotificationStore.recentModel.count > 0
                width: countText.contentWidth + 12
                height: 18
                radius: 9
                color: Colorscheme.primary_container
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: NotificationStore.recentModel.count
                    color: Colorscheme.on_primary_container
                    font.family: Sizes.fontFamilyMono
                    font.pixelSize: Sizes.font.xs
                    font.bold: true
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // 清除按钮
            Text {
                text: "Clear All"
                visible: NotificationStore.recentModel.count > 0
                color: Colorscheme.primary
                font.family: Sizes.fontFamilyMono
                font.pixelSize: Sizes.font.sm
                font.underline: true
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationStore.clearAll()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 1
            color: Colorscheme.outline; opacity: 0.2
        }

        // 通知列表
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Sizes.spacing.md
            
            model: NotificationStore.recentModel

            // 空状态提示
            Text {
                anchors.centerIn: parent
                visible: NotificationStore.recentModel.count === 0
                text: "No new notifications"
                color: Colorscheme.on_surface_variant
                font.family: Sizes.fontFamily
                font.pixelSize: Sizes.font.lg
                opacity: 0.5
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 60
                color: "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    spacing: Sizes.spacing.md

                    // 1. 图标容器
                    Rectangle {
                        width: 40; height: 40; radius: Sizes.rounding.normal
                        color: Colorscheme.surface_container_highest
                        
                        // A. 图片图标 (如果有)
                        Image {
                            id: iconImg
                            anchors.fill: parent
                            anchors.margins: 6
                            source: model.imagePath
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready && model.imagePath !== ""
                            smooth: true
                        }
                        
                        // B. 默认气泡图标 (无图时显示)
                        // 【修改】这里不再显示首字母，而是显示气泡图标
                        Text {
                            anchors.centerIn: parent
                            text: "\uf0e5" // FontAwesome Comment-alt 图标
                            visible: !iconImg.visible
                            color: Colorscheme.on_surface_variant
                            // 这里要确保用支持图标的字体，通常 Nerd Font 兼容 FontAwesome
                            font.family: Sizes.fontAwesome 
                            // 如需切换 Nerd Font, 改用 Sizes.fontFamilyMono
                            // font.family: Sizes.fontFamilyMono 
                            font.pixelSize: Sizes.font.xxl
                        }
                    }

                    // 2. 文字内容
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: model.appName
                                color: Colorscheme.primary
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.xs
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: model.time
                                color: Colorscheme.on_surface_variant
                                font.family: Sizes.fontFamilyMono
                                font.pixelSize: Sizes.font.xs
                                opacity: 0.7
                            }
                        }

                        Text {
                            text: model.summary
                            color: Colorscheme.on_surface
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.md
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        Text {
                            text: model.body
                            color: Colorscheme.on_surface_variant
                            font.family: Sizes.fontFamily
                            font.pixelSize: Sizes.font.sm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            opacity: 0.8
                        }
                    }
                    
                    // 单条删除
                    Text {
                        text: "×"
                        color: Colorscheme.on_surface_variant
                        font.pixelSize: Sizes.font.xxl
                        MouseArea {
                            anchors.fill: parent
                            onClicked: NotificationStore.dismissByRowId(model.dbId)
                        }
                    }
                }
            }
            
            // 动画效果
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { property: "y"; from: -20; duration: 200 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                NumberAnimation { property: "height"; to: 0; duration: 200 }
            }
        }
    }
}
