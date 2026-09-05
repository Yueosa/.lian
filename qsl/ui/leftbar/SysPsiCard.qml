// SysPsiCard — 压力（PSI）卡（SystemPage 中部拆出的容器卡）
//
// 容器卡：背景/圆角由宿主 RailContainer 提供，本卡只装内容
// 高度随展开态变化：空闲时收成窄条（三个 0.0 加三条平线不值一整行）

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    // 宽度跟随宿主容器（RailPage 按页给宽），不写死
    anchors.fill: parent
    implicitHeight: psiCard.height + 32   // 上下各 16 留白

    readonly property color cpuColor: Color.primary
    readonly property color memColor: Color.secondary

    // 压力（PSI）取代 Load：0–100 的百分比，直接读作
    // 「过去 10 秒有多少时间被卡住」，且 CPU / IO / 内存分得清。
    //
    // 健康系统上这三个数几乎恒为 0——这正是它有用的地方，但光看
    // 一个 0.0 等于没有。所以每项都配一条历史曲线（自适应量程，
    // minSpan 兜底避免把 0.02 的噪声放大成大波浪），
    // 并在近期出现过明显尖峰时才把峰值数字显示出来。
    Rectangle {
        id: psiCard

        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.rightMargin: 16

        // 三项里最坏的近期峰值。用峰值而非当前值做展开条件：
        // 卡顿过去后详情还会多留一会儿（直到尖峰滑出 60 点环形缓冲），
        // 否则等你低头看时它已经收回去了。
        readonly property real worstPeak: Math.max(
            Sysmon.psiCpuPeak, Sysmon.psiIoPeak, Sysmon.psiMemPeak)
        // 1% 即「10 秒里有 100ms 被卡住」，低于此不值得占一整行
        readonly property bool expanded:
            Sysmon.psiAvailable && worstPeak >= 1
        readonly property color severity:
            worstPeak >= 10 ? Color.error : Color.primary

        // 空闲时收成窄条：三个 0.0 加三条平线不值一整行。
        // 展开态 58 是给「当前值 + 峰值」两行数字留的高度
        height: (expanded || !Sysmon.psiAvailable) ? 58 : 34
        Behavior on height {
            Anim { type: Anim.Spatial }
        }

        radius: Size.rounding.lg
        color: Color.surfaceContainerHigh
        border.width: Style.border.width
        border.color: psiCard.expanded
            ? Color.withAlpha(psiCard.severity, 0.45)
            : Color.withAlpha(Color.outlineVariant, Style.border.opacity)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Size.spacing.md
            anchors.rightMargin: Size.spacing.md
            spacing: Size.spacing.sm

            Text {
                text: Sysmon.psiAvailable ? "PSI" : "Load"
                color: psiCard.expanded ? psiCard.severity : Color.textMuted
                font.pixelSize: Size.fontSize.bodySmall
            }
            // 空闲态靠它把「无阻塞」推到右边；展开后必须让位，
            // 否则它跟三条火花线抢同一份余量
            Item { Layout.fillWidth: !psiCard.expanded }

            // 空闲态只留一句话——异常时它消失、三栏顶上来，变化本身就是信号
            Text {
                visible: Sysmon.psiAvailable && !psiCard.expanded
                text: "无阻塞"
                color: Color.withAlpha(Color.textMuted, 0.75)
                font.pixelSize: Size.fontSize.labelMedium
            }

            // 内核没开 PSI 就退回 loadavg
            Text {
                visible: !Sysmon.psiAvailable
                text: Sysmon.load1.toFixed(2)
                color: Color.text
                font.pixelSize: Size.fontSize.titleSmall
                font.bold: true
                font.family: Size.fontMono
            }

            Repeater {
                // 收起时 model 置空，三个 Canvas 直接不存在。
                // 只把它们设成 invisible 的话，数据每到一次仍会走一遍
                // requestPaint，白烧 CPU。
                model: psiCard.expanded ? [
                    {
                        label: "CPU", v: Sysmon.psiCpu, c: root.cpuColor,
                        hist: Sysmon.psiCpuHistory, peak: Sysmon.psiCpuPeak
                    },
                    {
                        label: "IO", v: Sysmon.psiIo, c: Color.tertiary,
                        hist: Sysmon.psiIoHistory, peak: Sysmon.psiIoPeak
                    },
                    {
                        label: "内存", v: Sysmon.psiMem, c: root.memColor,
                        hist: Sysmon.psiMemHistory, peak: Sysmon.psiMemPeak
                    }
                ] : []

                // 每项两行：上行「标签 曲线 当前值」，下行右对齐的峰值。
                //
                // 峰值原先是横着排在当前值右边的，每项要多占约 48px，三项
                // 就是 144px——比整个「内存」组还宽。三项同时飙高、三个峰值
                // 一起冒出来时这行无论如何塞不下，只能从右边切掉，实测最坏
                // 情况整个「内存」组连线带数字全没了。竖着叠则一格不多占：
                // 「峰100.0」和「88.8」差不多宽，列宽由两者取大。
                ColumnLayout {
                    id: grp
                    required property var modelData
                    spacing: 0
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Text {
                            text: grp.modelData.label
                            color: Color.withAlpha(Color.textMuted, 0.8)
                            font.pixelSize: Size.fontSize.labelSmall
                        }
                        Sparkline {
                            // 三条火花线是这行里唯一可伸缩的东西。原先它固定
                            // 30、数字是刚性的，撑爆了只能裁字。现在反过来：
                            // 挤的时候先压曲线，数字一个都不许丢。
                            Layout.fillWidth: true
                            Layout.preferredWidth: 30
                            Layout.minimumWidth: 16
                            Layout.preferredHeight: 18
                            Layout.alignment: Qt.AlignVCenter
                            visible: grp.modelData.hist.length > 1
                            values: grp.modelData.hist
                            // 自适应量程：PSI 常年贴 0，固定 0–100 会画成死线
                            maxValue: 0
                            minSpan: 5
                            lineColor: grp.modelData.peak >= 10
                                ? Color.error : grp.modelData.c
                            lineWidth: 1.2
                            cornerRadius: Size.rounding.sm
                            backgroundColor: Color.withAlpha(Color.background, 0.45)
                        }
                        Text {
                            // 超过 10% 说明真的在卡，标红
                            text: grp.modelData.v.toFixed(1)
                            color: grp.modelData.v >= 10
                                ? Color.error : grp.modelData.c
                            font.pixelSize: Size.fontSize.titleSmall
                            font.bold: true
                            font.family: Size.fontMono
                        }
                    }

                    Text {
                        // 当前已回落但近期卡过——这才是最该看见的信息。
                        // 用 opacity 不用 visible：峰值是来去无常的，让它一直
                        // 占着位子，上面那行才不会跟着一惊一乍地上下跳
                        Layout.alignment: Qt.AlignRight
                        opacity: (grp.modelData.peak >= 1
                            && grp.modelData.peak > grp.modelData.v + 0.5) ? 1 : 0
                        text: "峰" + grp.modelData.peak.toFixed(1)
                        color: Color.withAlpha(Color.textMuted, 0.75)
                        font.pixelSize: Size.fontSize.labelSmall
                        font.family: Size.fontMono
                        Behavior on opacity { Anim { type: Anim.EffectsSlow } }
                    }
                }
            }
        }
    }
}
