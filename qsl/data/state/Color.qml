pragma Singleton

// ============================================================
// 配色方案 — Color
// ============================================================
// auto 模式读取 ~/.cache/quickshell_colors.json（lianwall → update_theme_from_wallpaper.sh）
//
// 注意：不要用 onSurface / onPrimary 这种属性名。
// QML 会把 onXxx 当成 Xxx 的信号处理器，导致颜色读到默认黑。
// ============================================================
// 对外接口一览：
//
// 模式：mode = "auto" / "light" / "dark"
// 文本：text / textMuted / textOnPrimary
// 表面：background / surface / surfaceHigh / surfaceHighest
// 品牌：primary / secondary / tertiary / error
// 装饰：outline / outlineVariant / secondaryFixed / shadow
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string mode: "auto"

    readonly property var _lightPalette: ({
        primary: "#b53f80",
        on_primary: "#ffffff",
        background: "#f7f8ff",
        surface: "#fbf8ff",
        surface_container_high: "#efecf7",
        surface_container_highest: "#e8e6f2",
        on_background: "#1b1d2a",
        on_surface: "#1b1d2a",
        on_surface_variant: "#44485c",
        secondary: "#4d5ba7",
        tertiary: "#8a4d84",
        error: "#ba1a1a",
        outline: "#74788d",
        outline_variant: "#c4c7dc",
        secondary_fixed: "#d879b2",
        shadow: "#d879b2",
    })

    readonly property var _darkPalette: ({
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

    property var _palette: root._darkPalette
    property int revision: 0

    readonly property color primary: _c("primary")
    readonly property color background: _c("background")
    readonly property color surface: _c("surface")
    readonly property color surfaceHigh: _c("surface_container_high")
    readonly property color surfaceHighest: _c("surface_container_highest")
    readonly property color secondary: _c("secondary")
    readonly property color tertiary: _c("tertiary")
    readonly property color error: _c("error")
    readonly property color outline: _c("outline")
    readonly property color outlineVariant: _c("outline_variant")
    readonly property color secondaryFixed: _c("secondary_fixed")
    readonly property color shadow: _c("shadow")

    // 文本色：避开 onXxx 命名
    readonly property color text: _c("on_surface")
    readonly property color textMuted: _c("on_surface_variant")
    readonly property color textOnPrimary: _c("on_primary")
    readonly property color textOnBackground: _c("on_background")

    function _c(snakeKey) {
        void revision
        const raw = (_palette || {})[snakeKey]
        if (raw === undefined || raw === null || raw === "")
            return "#00000000"
        return String(raw)
    }

    function withAlpha(base, alpha) {
        return Qt.rgba(base.r, base.g, base.b, Math.max(0, Math.min(1, alpha)))
    }

    function applyPalette(obj) {
        if (!obj || typeof obj !== "object")
            return
        _palette = Object.assign({}, obj)
        revision += 1
    }

    function reloadFromMode() {
        if (mode === "light") {
            applyPalette(_lightPalette)
            return
        }
        if (mode === "dark") {
            applyPalette(_darkPalette)
            return
        }
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
            if (root.mode !== "auto")
                return
            try {
                const text = _colorFile.text()
                if (!text)
                    return
                const parsed = JSON.parse(text)
                if (!parsed || Object.keys(parsed).length < 5)
                    return
                root.applyPalette(parsed)
            } catch (e) {}
        }
        onFileChanged: reload()
        onLoadFailed: {
            if (root.mode === "auto")
                root.applyPalette(root._darkPalette)
        }
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
        onTriggered: {
            if (root.mode === "auto")
                _colorFile.reload()
        }
    }

    onModeChanged: reloadFromMode()
    Component.onCompleted: reloadFromMode()
}
