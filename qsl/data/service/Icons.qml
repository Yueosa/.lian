pragma Singleton

// ============================================================
// 图标解析 — Icons
// ============================================================
// 「把一个应用标识翻译成一条能显示的图标 URL」只此一家。
//
// 第 9 轮从三处收上来的，三处原先各写各的，其中两处连函数名都一样：
//
//   ui/bar/TrayItem.qml        detectBundledAppId()  认「腾讯」不认「tim」
//   data/service/AppSearch.js  detectBundledAppId()  认「tim」不认「腾讯」
//   ui/notif/NotifCenter.qml   iconSourceFor()       唯一一处会先验证主题图标
//
// 前两个问的是同一个问题、给的答案不一样；第三个握着一条前两个都不知道的知识
// （见下面 theme() 的注释）。合并之后三处都拿到并集。
// ============================================================

import QtQuick
import Quickshell

Singleton {
    id: root

    // ============================================================
    // 主题图标
    // ============================================================
    // 必须先用 iconPath(name, true) 验证存在，不能直接拼 "image://icon/" 交给
    // Image 再等它报错。
    //
    // 这条是踩出来的：图标 provider 查不到名字时**不会**把 Image.status 置成
    // Error，而是交回一张品红/黑格子的占位图，status 照样是 Ready。于是所有
    // 「等 Image.Error 再回退」的写法都永远不触发，界面上直接糊一块格子。
    // iconPath 的第二个参数 = 允许失败，查不到返回空串，据此提前挡掉。
    function theme(name) {
        if (!name)
            return ""
        const n = String(name)
        return Quickshell.iconPath(n, true) ? "image://icon/" + n : ""
    }

    // 同上但先转小写。图标主题里的文件名是 qq.png，而通知的 desktopEntry
    // 字段存的是 "QQ"、SNI 的 icon 字段也常是首字母大写的。
    function themeLower(name) {
        return root.theme(String(name || "").toLowerCase())
    }

    // ============================================================
    // 路径
    // ============================================================
    // 已经是 URL 的原样放行——Quickshell 给 SNI 图标和通知图片的常常是
    // image://qsimage/... 这种进程内句柄，碰都不要碰。
    // 裸绝对路径补 file://。其余（相对路径、图标名）交回空串，由调用方转去查主题。
    function fromPath(p) {
        const s = String(p || "")
        if (!s.length)
            return ""
        if (s.startsWith("file://") || s.startsWith("image://"))
            return s
        if (s.startsWith("/"))
            return "file://" + s
        return ""
    }

    // ============================================================
    // 自带社交 SVG
    // ============================================================
    // asset/app-logo 下有四张。留着是因为这四个应用自己给的图标要么是进程内
    // 句柄（重启即失效）、要么压根不给、要么是一张糊的位图。
    //
    // 路径走 Quickshell.shellDir。TrayItem 原先硬写
    // "$HOME/.lian/quickshell/assets/apps/"——那是改名前的仓库路径，早就不在
    // 了，于是整条 bundled 分支恒定失败：每个命中的托盘项都要先白加载一次、
    // 拿到 Image.Error、再走回退。日志里那几条 Could not load icon 就是这么来的。
    readonly property string logoDir: Quickshell.shellDir + "/asset/app-logo"

    readonly property var bundledIds: ["telegram", "wechat", "discord", "qq"]

    function bundled(appId) {
        const id = String(appId || "")
        if (!id.length || root.bundledIds.indexOf(id) < 0)
            return ""
        return "file://" + root.logoDir + "/" + id + ".svg"
    }

    // 子串命中但要求两侧不是字母数字。
    //
    // 为「tim」加的（TIM 是企业版 QQ 的旧包名）。AppSearch 那份原先写的是裸
    // indexOf("tim")，而它的干草堆里拼了应用名和 Exec——于是 Timeshift、
    // OpenJDK Java 21 Run(tim)e 这些全被判成 QQ，启动器里贴了一排企鹅。
    function hasToken(hay, tok) {
        const alnum = /[a-z0-9]/
        let i = hay.indexOf(tok)
        while (i >= 0) {
            const before = i > 0 ? hay[i - 1] : ""
            const after = i + tok.length < hay.length ? hay[i + tok.length] : ""
            if (!alnum.test(before) && !alnum.test(after))
                return true
            i = hay.indexOf(tok, i + 1)
        }
        return false
    }

    // haystack = 调用方把能拿到的标识串拼一起。字段名各家不同（托盘项是
    // id/icon/tooltipTitle，desktop entry 是 name/desktopId/execString），
    // 所以拼串留给调用方，这里只负责认。
    function bundledId(haystack) {
        const hay = String(haystack || "").toLowerCase()
        if (!hay.length)
            return ""
        if (hay.indexOf("telegram") >= 0)
            return "telegram"
        if (hay.indexOf("wechat") >= 0 || hay.indexOf("weixin") >= 0)
            return "wechat"
        if (hay.indexOf("discord") >= 0)
            return "discord"
        if (hay.indexOf("linuxqq") >= 0 || hay.indexOf("腾讯") >= 0
                || hay.indexOf("/opt/qq") >= 0 || root.hasToken(hay, "tim"))
            return "qq"
        // 裸 chrome_status_icon 不认：Electron 版 QQ 和 Cursor 的 SNI Id 都是
        // chrome_status_icon_N，只靠 Id 分不出谁是谁，得上面那几条认出来才算。
        if (root.hasToken(hay, "qq") && hay.indexOf("chrome_status_icon") < 0)
            return "qq"
        return ""
    }
}
