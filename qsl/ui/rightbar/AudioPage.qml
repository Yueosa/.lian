// AudioPage — Rightbar 声音页
// 视觉对齐 Network/Bluetooth：工具行 = 图标钮 + 右开关；百分比只在各卡片/行显示一次
//
// 性能：进页 detailActive；销毁停追踪；应用节点由 Volume Instantiator 订阅；无轮询

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Components
import qs.data.state
import qs.data.service

Item {
    id: root

    signal requestClose()

    Component.onCompleted: Volume.setDetailActive(true)
    Component.onDestruction: Volume.setDetailActive(false)

    function pctText(vol, muted) {
        return Math.round((muted ? 0 : vol) * 100) + "%"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Size.spacing.sm

        // 工具行：对齐 Network/BT 左钮组 —— [齿轮] [扬声器静音] [麦静音]
        // （无右侧开关：静音已是明确图标钮，再放 pill 会重复）
        RowLayout {
            Layout.fillWidth: true
            spacing: Size.spacing.sm

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                color: gearMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "settings"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Color.textMuted
                }
                MouseArea {
                    id: gearMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Volume.openPavucontrol()
                        root.requestClose()
                    }
                }
            }

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                opacity: Volume.hasSink ? 1 : 0.35
                color: sinkToolMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Volume.sinkMuted ? "volume_off" : "volume_up"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Volume.sinkMuted ? Color.error : Color.textMuted
                }
                MouseArea {
                    id: sinkToolMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Volume.hasSink
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Volume.toggleSinkMute()
                }
            }

            Rectangle {
                width: 36
                height: 36
                radius: Size.rounding.md
                opacity: Volume.hasSource ? 1 : 0.35
                color: micToolMa.containsMouse
                    ? Color.withAlpha(Color.text, 0.08)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: Volume.sourceMuted ? "mic_off" : "mic"
                    font.family: Size.fontIcon
                    font.pixelSize: Size.fontSize.xl
                    color: Volume.sourceMuted ? Color.error : Color.textMuted
                }
                MouseArea {
                    id: micToolMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Volume.hasSource
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: Volume.toggleSourceMute()
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 输出卡：图标 · 名 · % + 滑条（静音只在工具行开关）
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Volume.hasSink ? 88 : 52
            radius: Size.rounding.md
            color: Volume.hasSink && !Volume.sinkMuted
                ? Color.withAlpha(Color.primary, 0.12)
                : Color.withAlpha(Color.text, 0.06)
            Behavior on color { CAnim {} }
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.sm
                visible: Volume.hasSink

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.md

                    Text {
                        text: Volume.isHeadphone ? "headphones" : "volume_up"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.xl
                        color: Volume.sinkMuted ? Color.textMuted : Color.primary
                    }

                    Text {
                        text: Volume.sinkName || "默认输出"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Volume.sinkMuted ? Color.text : Color.primary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.pctText(Volume.sinkVolume, Volume.sinkMuted)
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.primary
                    }
                }

                QslSlider {
                    Layout.fillWidth: true
                    value: Volume.sinkVolume
                    muted: Volume.sinkMuted
                    onMoved: (v) => Volume.setSinkVolume(v)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !Volume.hasSink
                text: "未找到输出设备"
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
            }
        }

        // 输入卡：与输出同结构（紧凑一点）
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 88
            radius: Size.rounding.md
            color: Color.withAlpha(Color.text, 0.06)
            visible: Volume.hasSource
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: Size.spacing.sm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Size.spacing.md

                    Text {
                        text: Volume.sourceMuted ? "mic_off" : "mic"
                        font.family: Size.fontIcon
                        font.pixelSize: Size.fontSize.xl
                        color: Volume.sourceMuted ? Color.error : Color.textMuted
                    }

                    Text {
                        text: Volume.sourceName || "麦克风"
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.pctText(Volume.sourceVolume, Volume.sourceMuted)
                        font.bold: true
                        font.pixelSize: Size.fontSize.md
                        color: Color.primary
                    }
                }

                QslSlider {
                    Layout.fillWidth: true
                    value: Volume.sourceVolume
                    muted: Volume.sourceMuted
                    onMoved: (v) => Volume.setSourceVolume(v)
                }
            }
        }

        Text {
            text: "应用程序"
            font.pixelSize: Size.fontSize.sm
            font.bold: true
            color: Color.textMuted
            Layout.topMargin: 4
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Size.spacing.sm
            reuseItems: true
            model: Volume.appLinkGroups

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property var appNode: modelData ? modelData.source : null
                readonly property bool nodeReady: !!(appNode && appNode.ready)
                readonly property real appVol: nodeReady && appNode.audio
                    ? appNode.audio.volume
                    : 0
                readonly property bool appMuted: nodeReady && appNode.audio
                    ? appNode.audio.muted
                    : false

                width: ListView.view.width
                height: 88
                radius: Size.rounding.md
                color: Color.withAlpha(Color.text, 0.04)
                clip: true
                opacity: nodeReady ? 1 : 0.55

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: Size.spacing.sm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Size.spacing.md

                        Image {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignVCenter
                            asynchronous: true
                            sourceSize.width: 56
                            sourceSize.height: 56
                            source: Volume.appIconSource(row.appNode)
                            onStatusChanged: {
                                if (status === Image.Error)
                                    source = "image://icon/audio-card"
                            }
                        }

                        Text {
                            text: Volume.appDisplayName(row.appNode)
                            font.bold: true
                            font.pixelSize: Size.fontSize.md
                            color: Color.text
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: root.pctText(row.appVol, row.appMuted)
                            font.bold: true
                            font.pixelSize: Size.fontSize.md
                            color: Color.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 28
                            height: 28
                            radius: Size.rounding.sm
                            color: appMuteMa.containsMouse
                                ? Color.withAlpha(Color.text, 0.08)
                                : "transparent"
                            opacity: row.nodeReady ? 1 : 0.4

                            Text {
                                anchors.centerIn: parent
                                text: row.appMuted ? "volume_off" : "volume_up"
                                font.family: Size.fontIcon
                                font.pixelSize: Size.fontSize.md
                                color: row.appMuted ? Color.error : Color.textMuted
                            }
                            MouseArea {
                                id: appMuteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: row.nodeReady
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Volume.toggleAppMute(row.appNode)
                            }
                        }
                    }

                    QslSlider {
                        Layout.fillWidth: true
                        value: row.appVol
                        muted: row.appMuted
                        onMoved: (v) => {
                            if (row.nodeReady)
                                Volume.setAppVolume(row.appNode, v)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                text: Volume.hasSink ? "暂无播放中的应用" : "无输出设备"
                font.pixelSize: Size.fontSize.sm
                color: Color.textMuted
            }
        }
    }
}
