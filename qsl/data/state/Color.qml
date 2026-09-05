pragma Singleton

// ============================================================
// 配色方案 — Color
// ============================================================
// 只吃 matugen 产物：~/.cache/quickshell_colors.json，50 个 M3 角色全部暴露。
// 换壁纸或改 Config.theme.* 时逐色 CAnim 渐变，避免整表闪切。
//
// ---- 命名（第 5 轮定案）----
//   · 非 on_* 角色 = M3 角色名的 camelCase
//         surface_container_high → surfaceContainerHigh
//   · on_* 家族 = 去掉 on_、加 Text 后缀
//         on_primary_container   → primaryContainerText
//     为什么不用 M3 原名 onPrimaryContainer：QML 把 `onXxx:` 一律当信号
//     处理器解析。2026-09-04 实测三种写法——
//         property color onPrimary: "#v"   编译失败（Cannot assign to a signal）
//         property color onPrimary         裸声明可用
//         Behavior on onPrimary { }        Quickshell 直接崩
//     而每个要渐变的角色都得挂 Behavior，所以这条路是死的。后缀式保住了
//     M3 最要紧的那层信息——配对关系：底用 X，X 上的字用 XText。
//   · 别名只有两条：text = surfaceText、textMuted = surfaceVariantText
//     （244 处调用，且这两个确实比 M3 原名好读）。新增别名要在 plan.md 登记。
//
// ---- 用法 ----
// 想要"带色调的底"优先用 container 家族（primaryContainer + primaryContainerText），
// 对比度由 M3 标准保证；withAlpha 手搓叠色是下策，只在 M3 没给对应角色时用。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- 兜底调色板 ----
    // 50 个角色给齐。缺色不能是透明——脚本的降级路径（matugen 不在/失败）
    // 只写 source_color 和 primary 两个键，剩下 48 个得有值可用。
    // 值由 `matugen color hex "#88d0ec" --mode dark` 生成，主色沿用改造前那套
    readonly property var _fallbackPalette: ({
        primary: "#88d0ec",
        on_primary: "#003544",
        primary_container: "#004d61",
        on_primary_container: "#b8eaff",
        primary_fixed: "#b8eaff",
        on_primary_fixed: "#001f28",
        primary_fixed_dim: "#88d0ec",
        on_primary_fixed_variant: "#004d61",
        inverse_primary: "#09677f",
        secondary: "#b3cad5",
        on_secondary: "#1e333c",
        secondary_container: "#354a53",
        on_secondary_container: "#cfe6f1",
        secondary_fixed: "#cfe6f1",
        on_secondary_fixed: "#071e26",
        secondary_fixed_dim: "#b3cad5",
        on_secondary_fixed_variant: "#354a53",
        tertiary: "#c3c3eb",
        on_tertiary: "#2c2d4d",
        tertiary_container: "#434465",
        on_tertiary_container: "#e1e0ff",
        tertiary_fixed: "#e1e0ff",
        on_tertiary_fixed: "#171837",
        tertiary_fixed_dim: "#c3c3eb",
        on_tertiary_fixed_variant: "#434465",
        error: "#ffb4ab",
        on_error: "#690005",
        error_container: "#93000a",
        on_error_container: "#ffdad6",
        background: "#0f1416",
        on_background: "#dee3e6",
        surface: "#0f1416",
        on_surface: "#dee3e6",
        surface_variant: "#40484c",
        on_surface_variant: "#bfc8cc",
        surface_dim: "#0f1416",
        surface_bright: "#353a3d",
        surface_container_lowest: "#0a0f11",
        surface_container_low: "#171c1f",
        surface_container: "#1b2023",
        surface_container_high: "#252b2d",
        surface_container_highest: "#303638",
        inverse_surface: "#dee3e6",
        inverse_on_surface: "#2c3134",
        outline: "#8a9296",
        outline_variant: "#40484c",
        shadow: "#000000",
        scrim: "#000000",
        surface_tint: "#88d0ec",
        source_color: "#88d0ec"
    })

    property var _palette: root._fallbackPalette
    property int revision: 0
    // 首帧 / 首次落盘不动画，之后换壁纸或改配色方案才渐变
    property bool _animateColors: false

    // ============================================================
    // 50 个角色
    // ============================================================
    // 每条两行：绑定 + 换主题渐变。
    // 用绑定而不是在 applyPalette 里逐个赋值，是为了让兜底值只有
    // _fallbackPalette 一处；原来内联默认值和兜底表把同一批颜色抄了两遍。
    // 不写 readonly：Behavior 要能截住写入。

    // ---- 主色 primary ----
    property color primary: root._colorOf("primary")
    Behavior on primary { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryText: root._colorOf("on_primary")
    Behavior on primaryText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryContainer: root._colorOf("primary_container")
    Behavior on primaryContainer { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryContainerText: root._colorOf("on_primary_container")
    Behavior on primaryContainerText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryFixed: root._colorOf("primary_fixed")
    Behavior on primaryFixed { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryFixedText: root._colorOf("on_primary_fixed")
    Behavior on primaryFixedText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryFixedDim: root._colorOf("primary_fixed_dim")
    Behavior on primaryFixedDim { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color primaryFixedVariantText: root._colorOf("on_primary_fixed_variant")
    Behavior on primaryFixedVariantText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color inversePrimary: root._colorOf("inverse_primary")
    Behavior on inversePrimary { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 副色 secondary ----
    property color secondary: root._colorOf("secondary")
    Behavior on secondary { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryText: root._colorOf("on_secondary")
    Behavior on secondaryText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryContainer: root._colorOf("secondary_container")
    Behavior on secondaryContainer { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryContainerText: root._colorOf("on_secondary_container")
    Behavior on secondaryContainerText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryFixed: root._colorOf("secondary_fixed")
    Behavior on secondaryFixed { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryFixedText: root._colorOf("on_secondary_fixed")
    Behavior on secondaryFixedText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryFixedDim: root._colorOf("secondary_fixed_dim")
    Behavior on secondaryFixedDim { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color secondaryFixedVariantText: root._colorOf("on_secondary_fixed_variant")
    Behavior on secondaryFixedVariantText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 第三色 tertiary ----
    property color tertiary: root._colorOf("tertiary")
    Behavior on tertiary { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryText: root._colorOf("on_tertiary")
    Behavior on tertiaryText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryContainer: root._colorOf("tertiary_container")
    Behavior on tertiaryContainer { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryContainerText: root._colorOf("on_tertiary_container")
    Behavior on tertiaryContainerText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryFixed: root._colorOf("tertiary_fixed")
    Behavior on tertiaryFixed { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryFixedText: root._colorOf("on_tertiary_fixed")
    Behavior on tertiaryFixedText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryFixedDim: root._colorOf("tertiary_fixed_dim")
    Behavior on tertiaryFixedDim { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color tertiaryFixedVariantText: root._colorOf("on_tertiary_fixed_variant")
    Behavior on tertiaryFixedVariantText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 错误 error ----
    property color error: root._colorOf("error")
    Behavior on error { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color errorText: root._colorOf("on_error")
    Behavior on errorText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color errorContainer: root._colorOf("error_container")
    Behavior on errorContainer { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color errorContainerText: root._colorOf("on_error_container")
    Behavior on errorContainerText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 背景与表面 surface ----
    property color background: root._colorOf("background")
    Behavior on background { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color backgroundText: root._colorOf("on_background")
    Behavior on backgroundText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surface: root._colorOf("surface")
    Behavior on surface { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceText: root._colorOf("on_surface")
    Behavior on surfaceText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceVariant: root._colorOf("surface_variant")
    Behavior on surfaceVariant { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceVariantText: root._colorOf("on_surface_variant")
    Behavior on surfaceVariantText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceDim: root._colorOf("surface_dim")
    Behavior on surfaceDim { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceBright: root._colorOf("surface_bright")
    Behavior on surfaceBright { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceContainerLowest: root._colorOf("surface_container_lowest")
    Behavior on surfaceContainerLowest { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceContainerLow: root._colorOf("surface_container_low")
    Behavior on surfaceContainerLow { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceContainer: root._colorOf("surface_container")
    Behavior on surfaceContainer { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceContainerHigh: root._colorOf("surface_container_high")
    Behavior on surfaceContainerHigh { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceContainerHighest: root._colorOf("surface_container_highest")
    Behavior on surfaceContainerHighest { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color inverseSurface: root._colorOf("inverse_surface")
    Behavior on inverseSurface { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color inverseSurfaceText: root._colorOf("inverse_on_surface")
    Behavior on inverseSurfaceText { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 描边与杂项 ----
    property color outline: root._colorOf("outline")
    Behavior on outline { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color outlineVariant: root._colorOf("outline_variant")
    Behavior on outlineVariant { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color shadow: root._colorOf("shadow")
    Behavior on shadow { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color scrim: root._colorOf("scrim")
    Behavior on scrim { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color surfaceTint: root._colorOf("surface_tint")
    Behavior on surfaceTint { enabled: root._animateColors; CAnim { type: CAnim.Theme } }
    property color sourceColor: root._colorOf("source_color")
    Behavior on sourceColor { enabled: root._animateColors; CAnim { type: CAnim.Theme } }

    // ---- 别名（就这两条）----
    // 跟着 surfaceText / surfaceVariantText 走，不需要各自的 Behavior
    property color text: root.surfaceText
    property color textMuted: root.surfaceVariantText

    // ---- 状态层透明度（M3 state layer，第 9 轮定案）----
    //
    // 「鼠标在上面」「正按着」这类反馈，M3 的做法是在原色上盖一层同色半透明，
    // 而不是换一个颜色。盘点前全树 33 处各写各的：中性色调用过 0.04 / 0.06 /
    // 0.08，强调色调用过 0.12 / 0.15 / 0.18 / 0.22 / 0.25 / 0.28，按下态用过
    // 0.14 / 0.16 / 0.24。同一件事九种写法，两个本该长得一样的地方不一样。
    //
    // 取值没照抄 M3 规范的 8%/10%：那是给浅色面设计的，本壳是暗色面 + 强调色
    // 叠加，8% 的 primary 在 #1b2023 上基本看不见。这里取的是现有写法里最常
    // 用的那档，所以落地后整体观感不变，变的是那些偏离的。
    readonly property QtObject state: QtObject {
        // 中性叠加：用在本来就有底色的行/卡上，只要"亮一点"
        readonly property real hover: 0.08
        readonly property real pressed: 0.16
        // 强调叠加：用在透明底的按钮/芯片上，悬停要显出可点
        readonly property real hoverAccent: 0.18
        readonly property real pressedAccent: 0.24
        // 选中态（比悬停重，且不随鼠标走）
        readonly property real selected: 0.18
    }

    // ============================================================
    // 取色与应用
    // ============================================================

    function _colorOf(snakeKey) {
        const raw = (root._palette || {})[snakeKey]
        if (raw === undefined || raw === null || raw === "") {
            // 单键兜底：调色板文件可能是脚本降级路径写的（只有两个键），
            // 缺的角色要退回兜底表而不是变透明
            const fb = root._fallbackPalette[snakeKey]
            return fb ? Qt.color(String(fb)) : Qt.rgba(0, 0, 0, 0)
        }
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
        // 50 个角色都是绑在 _palette 上的，改完这一行就全跟着变，
        // 不用在这里逐个赋值（那样兜底值得抄两遍）
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
    // 只当**路径字符串**用（传给下面的主题脚本）。绝不能把它交给 FileView：这条
    // 软链指向壁纸原文件，视频壁纸就是几百 MB，而 FileView 会把整个文件载进内存。
    // 详情见 Wallpaper.qml 里那段（那边同样的写法把 RSS 顶到了 4.4GB）。
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
        // 不直接 reload()：hook 用重定向写这份 JSON，inotify 在写第一段时就响，
        // 立刻去读会读到半截、JSON.parse 抛错、于是闪一下 fallback 配色。过 600ms
        // 再读，让写盘落定。
        //
        // 这个防抖原先挂在另一份 FileView 上——那份盯着壁纸软链（换壁纸 → 600ms 后
        // 重读配色）。软链指向的是壁纸原文件，视频壁纸下 FileView 会把 700MB 整个
        // 读进内存，所以那份拆了，防抖挪到这里。通知一点没少：配色本身就写在这份
        // JSON 里，hook 重写它就是「壁纸换了」最准的信号。
        onFileChanged: colorSettle.restart()
        onLoadFailed: root.applyFallback()
    }

    Timer {
        id: colorSettle
        interval: 600
        repeat: false
        onTriggered: root.reloadColors()
    }

    // ============================================================
    // 配置驱动的重新生成
    // ============================================================
    // matugen 的参数（配色方案 / 明暗 / 取色下标）在 Config 里。改了得重跑
    // 生成脚本，否则要等下一次换壁纸才生效——那就不叫热重载了。
    //
    // 判"要不要重跑"不靠"配置变过"这类时序标记，而是比对**调色板文件里记的
    // 参数**和**配置里现在要的参数**：脚本每次都把用了哪套参数写进 JSON
    // （__qs_scheme / __qs_request_mode / __qs_source_index），所以这个比对
    // 是无状态的，启动顺序怎么绕都不会误触发。
    // 代价是脚本挂了会想一直重试，用 _triedParams 挡住：同一组参数只试一次。
    // ============================================================

    readonly property string _paletteParams: {
        const p = _palette || {}
        const idx = p["__qs_source_index"]
        return String(p["__qs_scheme"] || "") + "|"
             + String(p["__qs_request_mode"] || "") + "|"
             + String(idx === undefined || idx === null ? "" : idx)
    }

    readonly property string _wantedParams:
        Config.theme.scheme + "|" + Config.theme.mode + "|" + Config.theme.sourceColorIndex

    // 已经试过的那组参数。脚本挂了的话 _paletteParams 永远追不上 _wantedParams，
    // 没这道闸就会无限重试
    property string _triedParams: ""

    readonly property bool _regenPending:
        _wantedParams !== _paletteParams && _wantedParams !== _triedParams

    function _maybeRegenerate() {
        if (!_regenPending)
            return
        _triedParams = _wantedParams
        _regen.running = true
    }

    // 合批：一次存盘里改了方案又改了明暗，只跑一次脚本。
    // 用 running 绑定而不是 onXChanged——`_` 开头的属性没有 onXChanged 写法
    // （qmllint 查不出来，只有运行期报 "Cannot assign to non-existent property"）。
    // repeat 保持 true：非重复的 Timer 触发后会自己写 running，那会打断上面的绑定
    Timer {
        id: regenSettle
        interval: 150
        repeat: true
        running: root._regenPending
        onTriggered: root._maybeRegenerate()
    }

    // 只传壁纸路径，参数由脚本自己读 config.json（同一份真源，见脚本 cfg_get）
    readonly property string _themeScriptPath:
        String(Qt.resolvedUrl("../../scripts/update_theme_from_wallpaper.sh")).replace("file://", "")

    Process {
        id: _regen
        command: ["bash", root._themeScriptPath, root._wallpaperLinkPath]
        onExited: (code) => {
            if (code !== 0)
                console.warn("Color: 重新生成配色失败，退出码", code)
            // 脚本写完 OUT_JSON，FileView 会自己收到变更；这里补一次是防
            // 写盘与 inotify 的竞态（Color 本来就靠 colorSettle 兜同类问题）
            root.reloadColors()
        }
    }

    Component.onCompleted: root.reloadColors()
}
