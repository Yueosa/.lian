// TodoRow — 待办行，TodoListCard（未完成）和 TodoDoneCard（已完成）共用
//
// 第 10 轮收编：两张卡原先各写一份，90 行几乎逐字相同。已完成那份其实就是
// 未完成那份把 done 冻成 true——勾选框填充、标题划掉、文字转灰，三处条件在
// 主列表那版里本来就写着，代进 done=true 就是已完成的样子。于是这里只留一份，
// 两个差异做成属性：星标（已完成不显示）和行高。
//
// 收编的动机不是省行数，是那条误触教训：星标和删除的热区曾经用
// anchors.margins:-4 各自外扩、吃掉中间间距而重叠，点星标右缘会误删。修在主
// 列表那份上，已完成那份只留了句「对齐主列表的误触教训」的转述——同一个坑的
// 修法和理由分家，下次改动只会修到一半。

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Rectangle {
    id: root

    // Todo.items 里的一条
    property var item: null
    // 已完成列表不给星标：那儿的操作只有「打回」和「删」
    property bool showStar: true
    // 单行内容时的行高下限（主列表 52、已完成 44）。内容换行后行高由文字
    // 实际高度撑开——见下面的 implicitHeight
    property int rowMinHeight: 52

    // 行高随内容自适应。
    //
    // 以前行高由 delegate 写死（52 / 44），文字又限死一行 + elide：22 个字的
    // 待办被截成「SuperJ有bug, 导致无法滚…」——用户报的「todo 显示不全」。
    // 现在标题允许换行（最多 3 行），行高取内容实际高度；短内容仍由
    // rowMinHeight 兜住，观感与改前一致
    implicitHeight: Math.max(root.rowMinHeight,
        contentRow.implicitHeight + Size.spacing.sm * 2)

    radius: Size.rounding.md
    color: Color.surfaceContainerLow

    QslStateLayer { source: hoverMa }

    MouseArea {
        id: hoverMa
        anchors.fill: parent
        hoverEnabled: true
    }

    RowLayout {
        id: contentRow
        // 不 anchors.fill：纵向要留出「由内容撑高」的余地（fill 会把行高钉死，
        // implicitHeight 永远等于外部高度，换行就又被裁掉）
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Size.spacing.md
        anchors.rightMargin: Size.spacing.md
        spacing: Size.spacing.sm

        // 勾选框：点一下在「完成 / 未完成」之间来回
        Rectangle {
            width: 24
            height: 24
            radius: Size.rounding.xs
            color: root.item && root.item.done ? Color.primary : "transparent"
            border.width: root.item && root.item.done ? 0 : 2
            border.color: Color.outlineVariant
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                visible: root.item && root.item.done
                text: "check"
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.lg
                font.variableAxes: ({ "opsz": 20 })
                color: Color.surfaceContainerLow
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.item) Todo.toggle(root.item.id)
            }
        }

        // 内容
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.item ? (root.item.text || "") : ""
                color: root.item && root.item.done ? Color.textMuted : Color.text
                font.pixelSize: Size.fontSize.bodyMedium
                font.strikeout: root.item ? !!root.item.done : false
                // 换行显示全文（最多 3 行，再多才截断）——同 NotifEntryRow 的
                // wrap + maximumLineCount + elide 组合。行高由 root.implicitHeight
                // 跟着长，见文件头
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Text {
                visible: text.length > 0
                text: {
                    if (!root.item)
                        return ""
                    const t = root.item.tag || ""
                    const p = "T" + root.item.priority
                    return t.length > 0 ? t + " · " + p : p
                }
                color: Color.textMuted
                font.pixelSize: Size.fontSize.labelSmall
            }
        }

        // 两个按钮都给固定尺寸，热区严格等于自身：
        // 原先用 anchors.margins:-4 各自外扩，正好吃掉中间的
        // 间距而互相重叠，点星标右缘会误触删除
        Item {
            visible: root.showStar
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter

            // 24 正是这个字体 opsz 轴的默认值，也就是轮廓的原生
            // 设计尺寸，不用再拿 opsz 去补偿缩小造成的笔画变细
            Text {
                anchors.centerIn: parent
                text: "star"
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.xxl
                font.variableAxes: ({ "FILL": root.item && root.item.starred ? 1 : 0 })
                color: root.item && root.item.starred ? Color.primary : Color.textMuted
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.item) Todo.star(root.item.id)
            }
        }

        // 用 opacity 而非 visible：RowLayout 会把不可见项踢出布局，
        // 于是每次划过一行，垃圾桶冒出来都把左边整排往左推一下
        Item {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
            opacity: hoverMa.containsMouse ? 1 : 0
            Behavior on opacity {
                Anim { type: Anim.EffectsFast }
            }

            Text {
                anchors.centerIn: parent
                text: "delete"
                font.family: Size.fontIcon
                font.pixelSize: Size.iconSize.xxl
                color: Color.error
            }
            MouseArea {
                anchors.fill: parent
                enabled: hoverMa.containsMouse
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.item) Todo.remove(root.item.id)
            }
        }
    }
}
