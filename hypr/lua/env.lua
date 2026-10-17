-- 环境变量配置
--     设置 Hyprland 会话级环境变量
--     这些变量会被所有子进程继承（包括 systemd user services 和 GUI 应用）
--     与 autostart.lua 的 import-env 配合，确保 systemd 服务也能读取


-- ============================================================
-- Wayland / Qt 平台
-- ============================================================

-- 声明会话类型为 Wayland
hl.env("XDG_SESSION_TYPE", "wayland")

-- Qt 应用在 Wayland 下运行（fallback xcb 兼容旧应用）
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Qt 自动缩放
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
-- Qt 使用 qt6ct 作为主题引擎
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")


-- ============================================================
-- 输入法（fcitx5）
--     此前这里什么都没设，Qt 应用只能退回 Wayland 的 text-input-v3。
--     该协议要求表面拿到 text-input 焦点，而 Quickshell 的 layer-shell 面板
--     用的是 layer surface + 独占键盘焦点，拿不到，于是 qs 页面里打不了中文。
--     指到 fcitx5-qt 插件后走 DBus，与表面类型无关。
--     GTK 侧刻意不设 GTK_IM_MODULE：GTK4 在 Wayland 下用 text-input 更好，
--     设了反而会退回旧路径。
-- ============================================================

hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")


-- ============================================================
-- 光标主题
--     Plana 是 Windows 光标方案转出的主题，只有 cursors/（XCursor），
--     没有 hyprcursors/ 目录，所以 Hyprland 走 XCursor 回退路径，
--     实际读取的是 XCURSOR_SIZE；HYPRCURSOR_* 保留是为了以后补
--     hyprcursor 格式时不用再改这里。
--     源文件是 32px 单档，这里设 24 会由 libxcursor 按最近邻缩放。
-- ============================================================

hl.env("XCURSOR_THEME", "Plana")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Plana")
hl.env("HYPRCURSOR_SIZE", "24")


-- ============================================================
-- Electron / Chromium 应用
--     让 Electron 应用（VS Code, Discord 等）自动使用 Wayland 原生渲染
--     避免 XWayland 下的模糊字体问题
-- ============================================================

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
