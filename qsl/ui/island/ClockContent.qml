// ClockContent — 一级岛时钟（滚动数字，对齐旧 qs）
// 性能：无独立 Timer，跟 Time.rawDate；四格 RollingDigit 常驻（体积极小）

import QtQuick
import qs.data.state
import qs.data.service

Item {
    id: root

    readonly property int digitFontSize: 22
    readonly property int digitCellHeight: Math.max(24, Math.round(digitFontSize * 1.15))

    readonly property string dateStr: Qt.formatDateTime(Time.rawDate, "ddd dd MMM")
    readonly property string hStr: Qt.formatDateTime(Time.rawDate, "HH")
    readonly property string mStr: Qt.formatDateTime(Time.rawDate, "mm")

    readonly property int h0: Number(hStr.charAt(0)) || 0
    readonly property int h1: Number(hStr.charAt(1)) || 0
    readonly property int m0: Number(mStr.charAt(0)) || 0
    readonly property int m1: Number(mStr.charAt(1)) || 0

    component RollingDigit: Item {
        id: digitContainer
        property int targetDigit: 0
        property color digitColor: Color.textOnBackground

        width: digitText.implicitWidth
        height: root.digitCellHeight
        clip: true
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: digitText
            text: "0\n1\n2\n3\n4\n5\n6\n7\n8\n9"
            color: digitContainer.digitColor
            font.family: Size.fontMono
            font.pixelSize: root.digitFontSize
            font.weight: Font.Black
            lineHeight: root.digitCellHeight
            lineHeightMode: Text.FixedHeight
            y: -digitContainer.targetDigit * root.digitCellHeight

            Behavior on y {
                SpringAnimation {
                    spring: 3.5
                    damping: 0.75
                    mass: 1.0
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Size.spacing.md

        Text {
            text: root.dateStr
            color: Color.primary
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.md
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "|"
            color: Color.outlineVariant
            font.family: Size.fontSans
            font.pixelSize: Size.fontSize.md
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter
            RollingDigit { targetDigit: root.h0 }
            RollingDigit { targetDigit: root.h1 }
            Text {
                text: ":"
                color: Color.textOnBackground
                font.family: Size.fontMono
                font.pixelSize: root.digitFontSize
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
            RollingDigit { targetDigit: root.m0 }
            RollingDigit { targetDigit: root.m1 }
        }
    }
}
