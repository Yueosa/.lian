// PlaceholderPage — Leftbar 占位（Sys / Weather 打磨前）
// 性能：极轻；无 service、无列表、无网络

import QtQuick
import qs.data.state

Item {
    id: root

    property string viewId: "sys"
    property string hint: "页面待打磨"

    Text {
        anchors.fill: parent
        anchors.margins: Size.spacing.sm
        text: root.hint
        color: Color.textMuted
        font.pixelSize: Size.fontSize.md
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignTop
    }
}
