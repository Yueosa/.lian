// PlaceholderPage — Rightbar 页面占位（四页打磨前共用）
// 性能：极轻；无 service 绑定、无列表、无扫描

import QtQuick
import qs.data.state

Item {
    id: root

    property string viewId: "network"
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
