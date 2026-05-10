import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root
    property string title: ""
    property string icon: ""
    property alias headerTools: headerToolsLayout.data 
    default property alias content: contentLayout.data
    property var closeAction: () => {} 

    Theme { id: theme }
    
    // 剥离背景色与边框，让底部固定的液态遮罩透出来！
    color: "transparent"
    border.color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.padding
        spacing: Sizes.spacing.lg

        RowLayout {
            Layout.fillWidth: true
            Text { text: root.icon; font.family: Sizes.fontIcon; font.pixelSize: Sizes.font.h1; color: theme.primary }
            Text { text: root.title; font.bold: true; font.pixelSize: Sizes.font.xxl; color: theme.text; Layout.fillWidth: true; Layout.leftMargin: 10 }
            
            RowLayout { id: headerToolsLayout; spacing: Sizes.spacing.md }
            
            Item { width: 12 }
            
            Text {
                text: "close"
                font.family: Sizes.fontIcon; font.pixelSize: Sizes.font.title; color: theme.subtext
                MouseArea { 
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeAction()
                }
            }
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true; Layout.fillHeight: true
        }
    }
}
