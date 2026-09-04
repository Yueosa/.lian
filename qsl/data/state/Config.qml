pragma Singleton

// ============================================================
// 用户偏好 — Config
// ============================================================
// qsl/config.json（仓内，跟着 git 走）→ 本单例 → Size/Color 转发 → UI
//
// 三条规矩（plan.md 架构约定 7）：
//   1. UI 永不直接写 `Config.*`，只写 `Size.*` / `Color.*`。可配的令牌由
//      Size 转发到这里，不可配的在 Size 里就是字面常量。这样加配置项不用
//      动调用点，也不会出现两个令牌来源共存。
//   2. 默认值的真源在本文件，JSON 只做覆盖。缺键、类型写错、文件不存在都
//      不该让 shell 挂——删掉 config.json 就等于恢复出厂。
//   3. 取值一律走 _num/_str/_bool/_enum，由它们做类型校验和回退。直接写
//      `_user.theme.scheme` 会在 JSON 写错时把 undefined 灌进绑定。
//
// 只收"真正想切换"的轴。spacing(211 处) / rounding(97 处) / fontSize(272 处)
// 这类细粒度令牌不进来：它们没有理由可配，而且一改就触发全局重排，还会点着
// 挂在这些属性上的所有 Behavior（见 plan.md 第 5 轮边界）。
// ============================================================

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // 用户覆盖。解析失败/文件不存在时保持 {}，即全部走默认值
    property var _user: ({})

    readonly property string configPath: {
        const base = Qt.resolvedUrl("../../config.json")
        return String(base).replace("file://", "")
    }

    // ============================================================
    // 取值助手：点分路径 + 类型校验 + 回退
    //   读 _user 的动作发生在绑定求值期间，所以依赖会被登记，
    //   改 JSON → _user 变 → 下面这些属性自动重算（热重载就是这么来的）
    // ============================================================

    function _raw(path) {
        const parts = String(path).split(".")
        let node = root._user
        for (let i = 0; i < parts.length; i++) {
            if (node === null || typeof node !== "object")
                return undefined
            node = node[parts[i]]
        }
        return node
    }

    function _num(path, def) {
        const v = root._raw(path)
        return (typeof v === "number" && isFinite(v)) ? v : def
    }

    function _str(path, def) {
        const v = root._raw(path)
        return (typeof v === "string" && v !== "") ? v : def
    }

    function _bool(path, def) {
        const v = root._raw(path)
        return (typeof v === "boolean") ? v : def
    }

    // 枚举写错了退回默认，别把垃圾喂给下游：
    // matugen 收到非法 scheme 会整条命令失败，那就成了"改个配置全屏没色"
    function _enum(path, allowed, def) {
        const v = root._raw(path)
        return (typeof v === "string" && allowed.indexOf(v) >= 0) ? v : def
    }

    function _clampInt(path, def, lo, hi) {
        return Math.round(Math.max(lo, Math.min(hi, root._num(path, def))))
    }

    // ============================================================
    // 壁纸配色（喂 scripts/update_theme_from_wallpaper.sh）
    // ============================================================

    // matugen --type scheme-<scheme> 的合法取值（2026-09-04 对着
    // `matugen image --help` 抄的，共 10 种；plan.md 里记的 9 种漏了 smart）
    readonly property var schemeValues: [
        "content", "expressive", "fidelity", "fruit-salad", "monochrome",
        "neutral", "rainbow", "smart", "tonal-spot", "vibrant"
    ]
    // auto = 按壁纸感知亮度自动判明暗（脚本里 luma>140 → light）
    readonly property var modeValues: ["auto", "light", "dark"]

    readonly property QtObject theme: QtObject {
        readonly property string scheme: root._enum("theme.scheme", root.schemeValues, "tonal-spot")
        readonly property string mode: root._enum("theme.mode", root.modeValues, "auto")
        // matugen 只认 0-4（0 = 最主要的色），超范围它自己不报错但取色会怪
        readonly property int sourceColorIndex: root._clampInt("theme.sourceColorIndex", 0, 0, 4)
    }

    // ============================================================
    // 字体家族（读取面在 Size.fontSans/fontMono/fontIcon，见约定 7）
    // ============================================================

    readonly property QtObject font: QtObject {
        readonly property string sans: root._str("font.sans", "Noto Sans CJK SC")
        readonly property string mono: root._str("font.mono", "JetBrainsMono Nerd Font")
        readonly property string icon: root._str("font.icon", "Material Symbols Outlined")
        readonly property string iconRounded: root._str("font.iconRounded", "Material Symbols Rounded")
    }

    // ============================================================
    // 动画
    // ============================================================

    readonly property QtObject anim: QtObject {
        // 总缩放：Size.anim 的七档时长全部乘它（曲线不动，只动时长）。
        // 0 = 时长归零 = 关掉动画；上限 4 是防手滑写成 40 把 shell 冻住
        readonly property real scale: Math.max(0, Math.min(4, root._num("anim.scale", 1.0)))
    }

    // ============================================================
    // 指针主题
    //   带保留：它散在 hypr/lua/env.lua 的 XCURSOR_THEME/HYPRCURSOR_THEME
    //   和两个 gtk settings.ini 里，且环境变量只对新启动的进程生效，
    //   做不到"改一下当场全系统换"（见 plan.md 第 5 轮）
    // ============================================================

    readonly property QtObject cursor: QtObject {
        readonly property string theme: root._str("cursor.theme", "BreezeX-RosePineDawn-Linux")
        readonly property int size: root._clampInt("cursor.size", 24, 8, 96)
    }

    // ============================================================
    // 面板几何与形态
    //   JSON 里按面板字母分组（panels.c.width），QML 侧摊平成 cWidth，
    //   免得为每个面板套一层 QtObject
    // ============================================================

    readonly property QtObject panels: QtObject {
        // C = leftrail：时间/系统/键位/待办四页同宽
        readonly property int cWidth: root._clampInt("panels.c.width", 400, 280, 900)
        // V = rightrail 上：368 对齐 N
        readonly property int vWidth: root._clampInt("panels.v.width", 368, 280, 900)
        // N = rightrail 下
        readonly property int nWidth: root._clampInt("panels.n.width", 368, 280, 900)
    }

    // ============================================================
    // 文件监听：改 JSON 存盘即生效，不用重启
    // ============================================================

    function reload() {
        _configFile.reload()
    }

    FileView {
        id: _configFile
        path: root.configPath
        watchChanges: true
        onLoaded: {
            try {
                const t = (_configFile.text() || "").trim()
                if (!t) {
                    root._user = ({})
                    return
                }
                const parsed = JSON.parse(t)
                root._user = (parsed && typeof parsed === "object") ? parsed : ({})
            } catch (e) {
                // 存到一半的半截 JSON 会走到这里。保留上一次的有效值而不是
                // 清空——编辑器写盘瞬间闪一下默认外观很难看
                console.warn("Config: config.json 解析失败，沿用上次的值:", e)
            }
        }
        onFileChanged: reload()
        // 文件不存在 = 全部默认，这是允许的状态，不报警
        onLoadFailed: root._user = ({})
    }

    Component.onCompleted: reload()
}
