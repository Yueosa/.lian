-- 窗口规则配置
--     控制特定应用的浮动/居中/大小/透明度/工作区分配
--     覆盖 Hyprland 的默认窗口行为


-- 窗口规则快捷封装，减少重复代码
local function appWindowRule(name, class, opts)
    opts = opts or {}
    opts.name = name
    opts.match = opts.match or { class = class }
    hl.window_rule(opts)
end


-- ============================================================
-- 浮动 + 居中 的应用
--     弹窗类工具，不适合平铺，应该浮动在屏幕中央
-- ============================================================

appWindowRule("pavucontrol-floating", "^(org.pulseaudio.pavucontrol)$", {
    float = true,
    size = "600 740",
    center = true,
})

appWindowRule("blueman-floating", "^(blueman-manager)$", {
    float = true,
    size = "560 800",
    center = true,
})

appWindowRule("tuxedo-control-center-floating", "^(tuxedo-control-center)$", {
    float = true,
    size = "1250 800",
    center = true,
})

appWindowRule("lianwall-gui-floating", "^(lianwall-gui)$", {
    float = true,
    size = "720 900",
    center = true,
})


-- ============================================================
-- xdg-desktop-portal 文件选择对话框
--     浏览器 / QQ 等应用调起的"打开文件"/"另存为"窗口
--     (?i) 忽略类名大小写（Xdg-desktop-portal-gtk / xdg-desktop-portal-gtk）
-- ============================================================

hl.window_rule({
    name = "portal-filepicker-float",
    match = { class = "(?i)^(xdg-desktop-portal-gtk)$" },
    float = true,
    center = true,
    size = "800 640",
})


-- ============================================================
-- QQ / 微信 子窗口浮动
--     图片查看器、视频查看器等弹窗不适合平铺
-- ============================================================

appWindowRule("qq-imageviewer-float", "^(QQ)$", {
    float = true,
    center = true,
    match = { class = "^(QQ)$", title = "^(图片查看器)$" },
})

appWindowRule("wechat-imageviewer-float", "^(wechat)$", {
    float = true,
    center = true,
    match = { class = "^(wechat)$", title = "^(图片和视频)$" },
})


-- ============================================================
-- 特殊平铺 / 工作区规则
-- ============================================================

-- QQ 主窗口平铺（图片查看器等子窗口已由上方规则处理为浮动）
appWindowRule("qq-tile", "^(QQ)$", {
    tile = true,
    match = { class = "^(QQ)$", title = "^(QQ)$" },
})

-- mihomo-party 固定在工作区 10
appWindowRule("mihomo-party-workspace", "^(mihomo-party)$", {
    workspace = "10 silent",
})


-- ============================================================
-- 透明度规则
-- ============================================================

-- kitty 终端始终不透明（透明终端难以阅读）
appWindowRule("kitty-opaque", "^(kitty)$", {
    opacity = "1.0 override",
})

-- Fcitx5 输入法候选窗口始终不透明
hl.window_rule({
    name = "fcitx5-input-opaque",
    match = { initial_title = "^(Fcitx5 Input Window)$" },
    opacity = "1.0 override",
})


-- ============================================================
-- 图层规则
-- ============================================================

-- wlogout 电源菜单：开启模糊 + 强制不透明背景
hl.layer_rule({
    name = "wlogout-blur",
    match = { namespace = "wlogout" },
    blur = true,
    ignore_alpha = 0,
})
