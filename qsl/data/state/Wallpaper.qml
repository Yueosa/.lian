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

    // current：主题 JSON 解析出的静态原图；否则走 current 软链
    readonly property string current: resolvedPath !== ""
        ? ("file://" + resolvedPath + "?v=" + version)
        : ("file://" + linkPath + "?v=" + version)

    // preview：永远走 preview 软链（应为降采样）；不要回落到 resolvedPath 原图
    readonly property string preview: "file://" + previewPath + "?v=" + version

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

    // 只把 FileView 挂在**小文件**上。
    //
    // 这里原先还有一份挂在 linkPath 上，只为「软链变了就 version += 1」，从不读它
    // 的内容。但 FileView 不管你读不读，它总把整个文件载进内存，而且跟随符号链接。
    // 换成视频壁纸后 current 指向一个 700MB 的 mp4，于是：700MB 进 QByteArray
    // （jemalloc 装进 768MiB 大块），再翻一倍成字符串（1536MiB）——Color.qml 里还有
    // 一份同样的写法，两份合起来 4.5GB。这些块用完就释放了，但 jemalloc 把页留在
    // dirty 缓存里不还给系统（stats 里 allocated 10MB / resident 4.23GB），所以
    // RSS 一启动就常驻 4.4GB，看着像泄漏，其实是一次性读进来的死重。
    //
    // 换壁纸的通知不缺这一份：主题 hook 最后会重写 colors.json（上面那份在看，
    // 且带 __qs_wallpaper_path），预览软链也会跟着换（下面这份，0.14MB）。
    FileView {
        path: root.previewPath
        watchChanges: true
        onFileChanged: root.version += 1
    }
}
