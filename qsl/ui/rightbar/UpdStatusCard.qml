// UpdStatusCard — updates 页首卡：数量大字 + 检查/升级
//
// 照 ~/Documents/qsl-v-designs.html：
//   12                                   [⟳ 检查] [⬆ 升级]
//   个包可更新 · 2 小时前检查
// 检查中细条 / 错误提示挂在下面，按需长出来
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: col.implicitHeight + Size.spacing.lg * 2

    signal requestClose()

    // 吃掉点击，避免穿透到 RailPage 点空白关闭层
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Size.spacing.lg
        spacing: Size.spacing.sm

        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.md

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: Updates.totalCount > 0 ? String(Updates.totalCount) : "—"
                    font.family: Size.fontMono
                    font.pixelSize: Size.fontSize.headlineSmall
                    font.bold: true
                    color: Updates.totalCount > 0 ? Color.primary : Color.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const parts = []
                        parts.push(Updates.totalCount > 0 ? "个包可更新" : "已是最新")
                        parts.push(Updates.updatedAgo
                            ? Updates.updatedAgo + "检查"
                            : "从未检查")
                        return parts.join(" · ")
                    }
                    font.pixelSize: Size.fontSize.labelSmall
                    color: Color.textMuted
                    elide: Text.ElideRight
                }
            }

            QslActionChip {
                text: Updates.loading ? "检查中…" : "检查"
                icon: "refresh"
                busy: Updates.loading
                enabled: !Updates.loading
                onClicked: Updates.refresh()
            }

            QslActionChip {
                text: "升级"
                icon: "system_update"
                filled: true
                enabled: Updates.totalCount > 0
                onClicked: {
                    Updates.openUpgrade()
                    root.requestClose()
                }
            }
        }

        // ---- 上次升级 ----
        Text {
            Layout.fillWidth: true
            visible: Updates.lastAppliedCount > 0
            text: "上次升级 " + Updates.lastAppliedCount + " 个包 · " + Updates.lastAppliedAgo
            font.pixelSize: Size.fontSize.labelSmall
            color: Color.textMuted
            elide: Text.ElideRight
        }

        // ---- 检查中细条 ----
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Updates.loading ? 3 : 0
            radius: 2
            color: Color.primaryContainer
            clip: true
            opacity: Updates.loading ? 1 : 0
            Behavior on Layout.preferredHeight {
                Anim { type: Anim.SpatialFast }
            }
            Behavior on opacity { Anim { type: Anim.EffectsFast } }

            Rectangle {
                width: parent.width * 0.35
                height: parent.height
                radius: 2
                color: Color.primary
                visible: Updates.loading

                // 装饰性/刷新动画，不走令牌（plan.md 白名单）
                SequentialAnimation on x {
                    running: Updates.loading
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -width
                        to: parent.width
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }

        // ---- 检查失败 ----
        Rectangle {
            Layout.fillWidth: true
            visible: !Updates.ok && !Updates.loading && Updates.errorAgo !== ""
            Layout.preferredHeight: visible ? 34 : 0
            radius: Size.rounding.sm
            color: Color.errorContainer
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: Size.spacing.sm

                Text {
                    text: "error"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.iconSize.md
                    color: Color.errorContainerText
                }
                Text {
                    Layout.fillWidth: true
                    text: "检查失败 · " + Updates.errorAgo
                    color: Color.errorContainerText
                    font.pixelSize: Size.fontSize.labelMedium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
