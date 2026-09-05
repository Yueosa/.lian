// ActiveWindow — 活动窗口名药丸
// 布局对齐旧 quickshell：RowLayout 自然测宽，标题只设 maximumWidth+elide
// 外层 displayWidth：变长立刻撑开，变短再收拢；收拢时 clip 裁切，不把 Text.width 掐死
//
// 性能：无 MultiEffect；无 TextMetrics；无图片

import QtQuick
import QtQuick.Layouts
import qs.data.service
import qs.data.state

Item {
    id: root

    readonly property int pillHeight: 36
    readonly property int hPad: 12
    readonly property int titleMax: 250

    implicitHeight: pillHeight
    implicitWidth: displayWidth
    width: displayWidth
    height: pillHeight
    clip: true

    // 内容真实宽度（与旧版 layout.width + 24 同构）
    readonly property real contentWidth: layout.implicitWidth + hPad * 2

    property real displayWidth: contentWidth

    onContentWidthChanged: {
        // 段宽直绑内容：变长也变短都走动画，段和耳朵才始终同步
        // （旧设计变长瞬移，是独立药丸时代的取舍）
        widthAnim.stop()
        widthAnim.from = displayWidth
        widthAnim.to = contentWidth
        widthAnim.start()
    }

    Anim {
        id: widthAnim
        target: root
        property: "displayWidth"
        // 药丸收拢用快档：长尾期布局一直变，时长压短
        type: Anim.SpatialFast
    }

    Component.onCompleted: displayWidth = contentWidth

    // 「活动窗口到底算不算存在」那套判断（换工作区后 activeToplevel 还指着旧窗）
    // 在 HyprService 里，这里只负责把空串显示成 Desktop
    readonly property string activeTitle: HyprService.activeTitle || "Desktop"

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Color.background
    }

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.hPad
        spacing: Size.spacing.md

        Text {
            text: ""
            color: Color.primary
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.labelLarge
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.activeTitle
            color: Color.primary
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.bodyMedium
            Layout.maximumWidth: root.titleMax
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
