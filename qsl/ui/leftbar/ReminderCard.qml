// ReminderCard — 工具页「提醒」容器卡（M2 填内容，目前是空态占位）
// M0 先把它立在这里占住「提醒」组，让芯片切换的容器交换动画有东西可换；
// M2 会换成真正的提醒，本文件不再保留占位文案
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import qs.data.state

Item {
    id: root

    anchors.fill: parent
    implicitHeight: 64 + 32

    // 工具页用：非「提醒」组时自报空（占位协议），值由 Leftbar 装配处覆盖
    property bool hasContent: true

    Text {
        anchors.centerIn: parent
        text: "提醒（开发中）"
        font.family: Size.fontSans
        font.pixelSize: Size.fontSize.bodyMedium
        color: Color.textMuted
    }
}
