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
-- 光标主题
--     XCursor 用于 XWayland 和传统应用
--     Hyprcursor 用于 Hyprland 原生渲染
--     两者设成同一主题以保持视觉一致
-- ============================================================

hl.env("XCURSOR_THEME", "BreezeX-RosePineDawn-Linux")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "BreezeX-RosePineDawn-Linux")
hl.env("HYPRCURSOR_SIZE", "24")


-- ============================================================
-- Electron / Chromium 应用
--     让 Electron 应用（VS Code, Discord 等）自动使用 Wayland 原生渲染
--     避免 XWayland 下的模糊字体问题
-- ============================================================

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
