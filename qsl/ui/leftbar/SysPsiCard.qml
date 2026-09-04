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

        // 空闲时收成窄条：三个 0.0 加三条平线不值一整行
        height: (expanded || !Sysmon.psiAvailable) ? 54 : 34
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
                font.pixelSize: Size.fontSize.sm
            }
            Item { Layout.fillWidth: true }

            // 空闲态只留一句话——异常时它消失、三栏顶上来，变化本身就是信号
            Text {
                visible: Sysmon.psiAvailable && !psiCard.expanded
                text: "无阻塞"
                color: Color.withAlpha(Color.textMuted, 0.75)
                font.pixelSize: Size.fontSize.sm
            }

            // 内核没开 PSI 就退回 loadavg
            Text {
                visible: !Sysmon.psiAvailable
                text: Sysmon.load1.toFixed(2)
                color: Color.text
                font.pixelSize: Size.fontSize.md
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

                RowLayout {
                    required property var modelData
                    spacing: 4

                    Text {
                        text: modelData.label
                        color: Color.withAlpha(Color.textMuted, 0.8)
                        font.pixelSize: Size.fontSize.xsm
                    }
                    Sparkline {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter
                        visible: modelData.hist.length > 1
                        values: modelData.hist
                        // 自适应量程：PSI 常年贴 0，固定 0–100 会画成一条死线
                        maxValue: 0
                        minSpan: 5
                        lineColor: modelData.peak >= 10 ? Color.error : modelData.c
                        lineWidth: 1.2
                        cornerRadius: Size.rounding.sm
                        backgroundColor: Color.withAlpha(Color.background, 0.45)
                    }
                    Text {
                        // 超过 10% 说明真的在卡，标红
                        text: modelData.v.toFixed(1)
                        color: modelData.v >= 10 ? Color.error : modelData.c
                        font.pixelSize: Size.fontSize.md
                        font.bold: true
                        font.family: Size.fontMono
                    }
                    Text {
                        // 当前已回落但近期卡过——这才是最该看见的信息
                        visible: modelData.peak >= 1
                            && modelData.peak > modelData.v + 0.5
                        text: "峰" + modelData.peak.toFixed(1)
                        color: Color.withAlpha(Color.textMuted, 0.75)
                        font.pixelSize: Size.fontSize.xsm
                        font.family: Size.fontMono
                    }
                }
            }
        }
    }
}
