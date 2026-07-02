pragma Singleton

// ============================================================
// 配色方案 — Color
// ============================================================
// 全局颜色真源。三种模式：
//   auto  → 从 matugen 生成的 JSON 读取（壁纸驱动）
//   light → 内置浅色调色板
//   dark  → 内置深色调色板
// ============================================================
// 对外接口一览：
//
// 模式（可读写）：
//   mode       string   "auto" / "light" / "dark"
//
// 品牌色：
//   primary          color   主色（按钮/强调）
//   onPrimary        color   主色上的文字
//
// 表面色（从低到高四层）：
//   background       color   最底层背景
//   surface          color   卡片/面板背景
//   surfaceHigh      color   悬浮层
//   surfaceHighest   color   顶层弹窗
//
// 内容色：
//   onBackground     color   背景上的文字
//   onSurface        color   表面上的文字
//   onSurfaceVariant color   次要文字/图标
//
// 强调色：
//   secondary        color   辅助色
//   tertiary         color   第三色
//   error            color   错误/警告
//
// 装饰色：
//   outline          color   边框
//   outlineVariant   color   弱边框
//   shadow           color   阴影
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============================================================
    // 模式
    // ============================================================

    property string mode: "dark"

    // ============================================================
    // 内置调色板 — 浅色
    // ============================================================

    readonly property var _lightPalette: ({
        primary:          "#b53f80",
        onPrimary:        "#ffffff",
        background:       "#f7f8ff",
        surface:          "#fbf8ff",
        surfaceHigh:      "#efecf7",
        surfaceHighest:   "#e8e6f2",
        onBackground:     "#1b1d2a",
        onSurface:        "#1b1d2a",
        onSurfaceVariant: "#44485c",
        secondary:        "#4d5ba7",
        tertiary:         "#8a4d84",
        error:            "#ba1a1a",
        outline:          "#74788d",
        outlineVariant:   "#c4c7dc",
        shadow:           "#d879b2",
    })

    // ============================================================
    // 内置调色板 — 深色
    // ============================================================

    readonly property var _darkPalette: ({
        primary:          "#88d0ec",
        onPrimary:        "#003544",
        background:       "#0f1416",
        surface:          "#0f1416",
        surfaceHigh:      "#1b2023",
        surfaceHighest:   "#252b2d",
        onBackground:     "#dee3e6",
        onSurface:        "#dee3e6",
        onSurfaceVariant: "#bfc8cc",
        secondary:        "#b3cad5",
        tertiary:         "#c3c3eb",
        error:            "#ffb4ab",
        outline:          "#8a9296",
        outlineVariant:   "#40484c",
        shadow:           "#000000",
    })

    // ============================================================
    // 当前活动调色板
    //     根据 mode 从内置调色板或 matugen JSON 中选取
    // ============================================================

    readonly property var _active: {
        if (mode === "light") return _lightPalette
        if (mode === "dark")  return _darkPalette
        // auto: 尝试读 matugen JSON
        const text = _colorFile.text()
        if (text) {
            try {
                const parsed = JSON.parse(text)
                if (Object.keys(parsed).length > 5) return parsed
            } catch (e) {}
        }
        // fallback: matugen 还没生成过，用深色
        return _darkPalette
    }

    // ============================================================
    // 公开属性（thin accessors，零开销）
    // ============================================================

    readonly property color primary:          _active["primary"]                    || Qt.rgba(0,0,0,0)
    readonly property color onPrimary:        _active["on_primary"]                 || _active["onPrimary"]         || Qt.rgba(0,0,0,0)
    readonly property color background:       _active["background"]                 || Qt.rgba(0,0,0,0)
    readonly property color surface:          _active["surface"]                    || Qt.rgba(0,0,0,0)
    readonly property color surfaceHigh:      _active["surface_container_high"]     || _active["surfaceHigh"]       || Qt.rgba(0,0,0,0)
    readonly property color surfaceHighest:   _active["surface_container_highest"]  || _active["surfaceHighest"]    || Qt.rgba(0,0,0,0)
    readonly property color onBackground:     _active["on_background"]              || _active["onBackground"]      || Qt.rgba(0,0,0,0)
    readonly property color onSurface:        _active["on_surface"]                 || _active["onSurface"]         || Qt.rgba(0,0,0,0)
    readonly property color onSurfaceVariant: _active["on_surface_variant"]         || _active["onSurfaceVariant"]  || Qt.rgba(0,0,0,0)
    readonly property color secondary:        _active["secondary"]                  || Qt.rgba(0,0,0,0)
    readonly property color tertiary:         _active["tertiary"]                   || Qt.rgba(0,0,0,0)
    readonly property color error:            _active["error"]                      || Qt.rgba(0,0,0,0)
    readonly property color outline:          _active["outline"]                    || Qt.rgba(0,0,0,0)
    readonly property color outlineVariant:   _active["outline_variant"]            || _active["outlineVariant"]    || Qt.rgba(0,0,0,0)
    readonly property color shadow:           _active["shadow"]                     || Qt.rgba(0,0,0,0)

    // ============================================================
    // matugen JSON 文件
    //     惰性读取，只在 mode === "auto" 时被引用
    // ============================================================

    readonly property string _colorFilePath:
        Quickshell.env("HOME") + "/.cache/quickshell_colors.json"

    FileView {
        id: _colorFile
        path: root._colorFilePath
    }

    // 外部（主题切换脚本）写入了新 JSON → 刷新
    onModeChanged: _colorFile.reload()
}
