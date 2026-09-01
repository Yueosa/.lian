pragma Singleton

// ============================================================
// 设计令牌 — Style
// ============================================================
// 统一视觉风格参数：阴影、边框、背景透明度、动画弹簧等。
// 与 Size（几何）、Color（色值）分工，此处只放「效果配方」。
// ============================================================

import QtQuick
import Quickshell

Singleton {
    id: root

    // ============================================================
    // 阴影 token（给 QslShadow 统一配方）
    // ============================================================

    readonly property QtObject shadow: QtObject {
        // 卡片（Card/面板）
        readonly property real cardBlur: 14
        readonly property real cardOffsetY: 3
        readonly property int cardLayers: 3
        readonly property real cardOpacity: 0.18

        // 浮层（FreeWindow/Popup）
        readonly property real floatBlur: 24
        readonly property real floatOffsetY: 6
        readonly property int floatLayers: 4
        readonly property real floatOpacity: 0.25

        // 轻量（按钮/badge/小元素）
        readonly property real lightBlur: 6
        readonly property real lightOffsetY: 1
        readonly property int lightLayers: 2
        readonly property real lightOpacity: 0.12
    }

    // ============================================================
    // 边框
    // ============================================================

    readonly property QtObject border: QtObject {
        readonly property real width: 1
        readonly property real opacity: 0.08
    }

    // ============================================================
    // 背景透明度（深色/浅色分离）
    // ============================================================

    readonly property QtObject bg: QtObject {
        readonly property real cardAlpha: 0.72
        readonly property real sidebarAlpha: 0.82
        readonly property real panelAlpha: 0.92
        readonly property real solidAlpha: 1.0
    }
}
