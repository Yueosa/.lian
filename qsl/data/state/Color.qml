pragma Singleton

// ============================================================
// 配色方案 — Color
// ============================================================
// 只吃 matugen 产物：~/.cache/quickshell_colors.json
// 换壁纸时对各 color 属性做 CAnim 渐变，避免整表闪切
//
// 注意：不要用 onSurface / onPrimary 这种属性名。
// ============================================================
// 对外接口：
//   text / textMuted / textOnPrimary / textOnBackground
//   background / surface / surfaceHigh / surfaceHighest
//   primary / secondary / tertiary / error
//   outline / outlineVariant / secondaryFixed / shadow
//   withAlpha(base, alpha)
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Components

Singleton {
    id: root

    readonly property var _fallbackPalette: ({
        primary: "#88d0ec",
        on_primary: "#003544",
        background: "#0f1416",
        surface: "#0f1416",
        surface_container_high: "#1b2023",
        surface_container_highest: "#252b2d",
        on_background: "#dee3e6",
        on_surface: "#dee3e6",
        on_surface_variant: "#bfc8cc",
        secondary: "#b3cad5",
        tertiary: "#c3c3eb",
        error: "#ffb4ab",
        outline: "#8a9296",
        outline_variant: "#40484c",
        secondary_fixed: "#88d0ec",
        shadow: "#000000",
    })

    property var _palette: root._fallbackPalette
    property int revision: 0
    // 首帧 / 首次落盘不动画，之后换壁纸才渐变
    property bool _animateColors: false

    property color primary: "#88d0ec"
    property color background: "#0f1416"
    property color surface: "#0f1416"
    property color surfaceHigh: "#1b2023"
    property color surfaceHighest: "#252b2d"
    property color secondary: "#b3cad5"
    property color tertiary: "#c3c3eb"
    property color error: "#ffb4ab"
    property color outline: "#8a9296"
    property color outlineVariant: "#40484c"
    property color secondaryFixed: "#88d0ec"
    property color shadow: "#000000"
    property color text: "#dee3e6"
    property color textMuted: "#bfc8cc"
    property color textOnPrimary: "#003544"
    property color textOnBackground: "#dee3e6"

    Behavior on primary {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on background {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on surface {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on surfaceHigh {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on surfaceHighest {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on secondary {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on tertiary {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on error {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on outline {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on outlineVariant {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on secondaryFixed {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on shadow {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on text {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on textMuted {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on textOnPrimary {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }
    Behavior on textOnBackground {
        enabled: root._animateColors
        CAnim { type: CAnim.Theme }
    }

    function _colorOf(snakeKey) {
        const raw = (_palette || {})[snakeKey]
        if (raw === undefined || raw === null || raw === "")
            return Qt.rgba(0, 0, 0, 0)
        return Qt.color(String(raw))
    }

    function withAlpha(base, alpha) {
        return Qt.rgba(base.r, base.g, base.b, Math.max(0, Math.min(1, alpha)))
    }

    function applyPalette(obj) {
        if (!obj || typeof obj !== "object")
            return
        _palette = Object.assign({}, obj)
        revision += 1

        primary = _colorOf("primary")
        background = _colorOf("background")
        surface = _colorOf("surface")
        surfaceHigh = _colorOf("surface_container_high")
        surfaceHighest = _colorOf("surface_container_highest")
        secondary = _colorOf("secondary")
        tertiary = _colorOf("tertiary")
        error = _colorOf("error")
        outline = _colorOf("outline")
        outlineVariant = _colorOf("outline_variant")
        secondaryFixed = _colorOf("secondary_fixed")
        shadow = _colorOf("shadow")
        text = _colorOf("on_surface")
        textMuted = _colorOf("on_surface_variant")
        textOnPrimary = _colorOf("on_primary")
        textOnBackground = _colorOf("on_background")

        if (!_animateColors)
            Qt.callLater(() => { root._animateColors = true })
    }

    function applyFallback() {
        applyPalette(_fallbackPalette)
    }

    function reloadColors() {
        _colorFile.reload()
    }

    readonly property string _colorFilePath:
        Quickshell.env("HOME") + "/.cache/quickshell_colors.json"
    readonly property string _wallpaperLinkPath:
        Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"

    FileView {
        id: _colorFile
        path: root._colorFilePath
        watchChanges: true
        onLoaded: {
            try {
                const text = _colorFile.text()
                if (!text) {
                    root.applyFallback()
                    return
                }
                const parsed = JSON.parse(text)
                if (!parsed || Object.keys(parsed).length < 5) {
                    root.applyFallback()
                    return
                }
                root.applyPalette(parsed)
            } catch (e) {
                root.applyFallback()
            }
        }
        onFileChanged: reload()
        onLoadFailed: root.applyFallback()
    }

    FileView {
        path: root._wallpaperLinkPath
        watchChanges: true
        onFileChanged: colorSettle.restart()
        onLoaded: colorSettle.restart()
    }

    Timer {
        id: colorSettle
        interval: 600
        repeat: false
        onTriggered: root.reloadColors()
    }

    Component.onCompleted: root.reloadColors()
}
