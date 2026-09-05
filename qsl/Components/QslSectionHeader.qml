// QslSectionHeader — 卡内分区标题（V 面板四页共用）
//
// 结构：标题 + 弹簧 + 尾部（note 文字 / 可点动作 / 任意嵌套件）
//   可用网络                              ⟳ 扫描
//   已保存                                   3 个
//
// 嵌套子项进尾部位（default property），note/action 是常见两种的快捷写法

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state

Item {
    id: root

    property string title: ""
    // 标题配色：默认正文色，给分节留个上色口（updates 用它区分 AUR / 官方）
    property color titleColor: Color.text
    // 纯说明文字（"3 个" / "扫描中…"）
    property string note: ""
    // 可点动作（"扫描"），带 actionIcon 时图标在前
    property string action: ""
    property string actionIcon: ""
    property bool actionBusy: false
    property bool actionEnabled: true
    signal actionClicked()

    default property alias trailingData: trailingRow.data

    implicitHeight: Math.max(titleText.implicitHeight, trailingRow.implicitHeight)

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.bold: true
        font.pixelSize: Size.fontSize.sm
        color: root.titleColor
        Behavior on color { CAnim {} }
    }

    RowLayout {
        id: trailingRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Size.spacing.sm

        Text {
            visible: root.note !== ""
            text: root.note
            font.pixelSize: Size.fontSize.xsm
            color: Color.textMuted
        }

        // 文字动作：图标 + 标签，整块可点
        Rectangle {
            visible: root.action !== ""
            implicitWidth: actionRow.implicitWidth + Size.spacing.md
            implicitHeight: 24
            radius: Size.rounding.full
            opacity: root.actionEnabled ? 1 : 0.4
            color: "transparent"

            QslStateLayer {
                source: actionMa
                active: root.actionEnabled
                tint: Color.primary
                accent: true
            }

            RowLayout {
                id: actionRow
                anchors.centerIn: parent
                spacing: Size.spacing.xs

                Text {
                    visible: root.actionIcon !== ""
                    text: root.actionIcon
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.sm
                    color: Color.textMuted

                    // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.actionBusy
                    }
                }

                Text {
                    text: root.action
                    font.pixelSize: Size.fontSize.xsm
                    color: Color.textMuted
                }
            }

            MouseArea {
                id: actionMa
                anchors.fill: parent
                enabled: root.actionEnabled
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.actionClicked()
            }
        }
    }
}
