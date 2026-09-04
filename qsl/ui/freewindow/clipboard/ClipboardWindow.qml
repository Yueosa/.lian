// ClipboardWindow — 剪贴板（Super+Z）
// 复用 FreeWindow 壳；无壁纸区，整张卡牌都是剪贴板列表

import QtQuick
import Quickshell
import qs.data.state
import qs.data.freewindow.clipboard
import qs.ui.freewindow

FreeWindow {
    id: root

    shellNamespace: "qsl-clipboard"

    onOpenChanged: {
        if (open) {
            // 先 hydrate 磁盘 JSON，再 reset/refresh，避免空窗闪一下
            Clipboard.hydrate()
            Qt.callLater(function() { clipboardPage.reset() })
        }
    }
    onContentActiveChanged: {
        // 退场动画结束后再清内存；JSON 缓存保留
        if (!contentActive)
            Clipboard.release()
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Color.withAlpha(Color.surfaceContainerHigh, Style.bg.panelAlpha)
        radius: Size.rounding.xxl

        ClipboardPage {
            id: clipboardPage
            anchors.fill: parent
            anchors.margins: 24
            onPasteRequested: root.closeWindow()
            onCloseRequested: root.closeWindow()
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Color.secondaryFixed
            border.width: 2
            radius: Size.rounding.xxl
        }
    }
}
