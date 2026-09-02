// AudioChip — 悬停整颗胶囊：输出图标+数字 | 输入图标+数字
// 滚轮：左半/默认调 sink，右半（有麦时）调 source；无点击

import QtQuick
import QtQuick.Layouts
import qs.Components
import qs.data.state
import qs.data.service

Rectangle {
    id: root

    property bool isHovered: mouseArea.containsMouse
    // 悬停意图：进入即锁存展开，由 RightBar 完全离开 1s 后统一回收（见 Bar.qml）
    property bool expanded: false

    onIsHoveredChanged: {
        if (isHovered)
            expanded = true
    }

    implicitHeight: 28
    implicitWidth: expanded ? Math.ceil(layout.implicitWidth) + 14 : 28
    radius: height / 2
    clip: true
    color: Color.withAlpha(Color.text, 0.08)

    Behavior on implicitWidth {
        Anim { type: Anim.SpatialFast }
    }

    readonly property int sinkPct: Math.round((Volume.sinkMuted ? 0 : Volume.sinkVolume) * 100)
    readonly property int sourcePct: Math.round((Volume.sourceMuted ? 0 : Volume.sourceVolume) * 100)

    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 7
        spacing: Size.spacing.xs

        // —— 输出 ——
        Text {
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.md
            Layout.alignment: Qt.AlignVCenter
            color: (Volume.sinkMuted || Volume.sinkVolume <= 0)
                ? Color.error
                : Color.primary
            text: {
                if (Volume.isHeadphone)
                    return "headphones"
                if (Volume.sinkMuted || Volume.sinkVolume <= 0)
                    return "volume_off"
                if (Volume.sinkVolume < 0.5)
                    return "volume_down"
                return "volume_up"
            }
        }

        Text {
            id: sinkLabel
            text: root.sinkPct.toString()
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.sm
            font.bold: true
            color: Color.text
            Layout.alignment: Qt.AlignVCenter
            opacity: root.expanded ? 1 : 0
            Layout.preferredWidth: root.expanded ? sinkLabel.implicitWidth : 0
            clip: true
            Behavior on opacity { Anim { type: Anim.EffectsFast } }
            Behavior on Layout.preferredWidth {
                Anim { type: Anim.SpatialFast }
            }
        }

        // —— 输入 ——
        Text {
            id: micIcon
            visible: Volume.hasSource
            font.family: Size.fontIcon
            font.pixelSize: Size.fontSize.md
            Layout.alignment: Qt.AlignVCenter
            color: (Volume.sourceMuted || Volume.sourceVolume <= 0)
                ? Color.error
                : Color.secondary
            text: Volume.sourceMuted ? "mic_off" : "mic"
            opacity: root.expanded ? 1 : 0
            Layout.preferredWidth: (root.expanded && Volume.hasSource)
                ? micIcon.implicitWidth
                : 0
            clip: true
            Behavior on opacity { Anim { type: Anim.EffectsFast } }
            Behavior on Layout.preferredWidth {
                Anim { type: Anim.SpatialFast }
            }
        }

        Text {
            id: sourceLabel
            visible: Volume.hasSource
            text: root.sourcePct.toString()
            font.family: Size.fontMono
            font.pixelSize: Size.fontSize.sm
            font.bold: true
            color: Color.text
            Layout.alignment: Qt.AlignVCenter
            opacity: root.expanded ? 1 : 0
            Layout.preferredWidth: (root.expanded && Volume.hasSource)
                ? sourceLabel.implicitWidth
                : 0
            clip: true
            Behavior on opacity { Anim { type: Anim.EffectsFast } }
            Behavior on Layout.preferredWidth {
                Anim { type: Anim.SpatialFast }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
        onWheel: (wheel) => {
            const step = 0.05
            const up = wheel.angleDelta.y > 0
            // 展开且指针在右半 → 调麦克风；否则调输出
            const micSide = Volume.hasSource && root.expanded
                && mouseX > width * 0.5
            if (micSide) {
                const cur = Volume.sourceVolume || 0
                Volume.setSourceVolume(up ? cur + step : cur - step)
            } else if (up) {
                Volume.volumeUp(step)
            } else {
                Volume.volumeDown(step)
            }
        }
    }
}
