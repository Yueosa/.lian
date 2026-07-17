pragma Singleton

// ============================================================
// 壁纸 — Wallpaper
// ============================================================
// lianwall hook 会更新：
//   ~/.cache/wallpaper_rofi/current         ← ln -sf 真图
//   ~/.cache/wallpaper_rofi/current_preview ← theme 脚本再 ln -sf 静态预览
//
// 主题 hook 最后会写 quickshell_colors.json，其中 __qs_wallpaper_path
// 是 UI 可显示的真实静态图片路径。直接监听该文件，不轮询、不启动 shell。
// ============================================================
// 对外接口一览：
//
// 属性（readonly）：
//   current   string   原图 file URL（真实路径 + ?v=）
//   preview   string   预览 file URL（真实路径 + ?v=，优先给 UI）
//   version   int      变化计数
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string linkPath:
        Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current"
    readonly property string previewPath:
        Quickshell.env("HOME") + "/.cache/wallpaper_rofi/current_preview"

    property int version: 0
    property string resolvedPath: ""

    readonly property string current: resolvedPath !== ""
        ? ("file://" + resolvedPath + "?v=" + version)
        : ("file://" + linkPath + "?v=" + version)

    readonly property string preview: resolvedPath !== ""
        ? ("file://" + resolvedPath + "?v=" + version)
        : ("file://" + previewPath + "?v=" + version)

    function loadThemeMetadata() {
        try {
            const text = themeFile.text()
            if (!text)
                return
            const parsed = JSON.parse(text)
            const path = String(parsed["__qs_wallpaper_path"] || "")
            if (path && path !== resolvedPath) {
                resolvedPath = path
                version += 1
            }
        } catch (e) {}
    }

    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.cache/quickshell_colors.json"
        watchChanges: true
        onLoaded: root.loadThemeMetadata()
        onFileChanged: reload()
    }

    // hook 的软链先于主题 JSON 更新；先 bump 一次让 UI 不粘旧缓存，
    // 随后 themeFile 会给出最终真实路径。
    FileView {
        path: root.linkPath
        watchChanges: true
        onFileChanged: root.version += 1
    }
}
