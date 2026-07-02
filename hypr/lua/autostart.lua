-- 会话生命周期管理
--     控制 Hyprland 启动/关闭时拉起和停止的服务
--
--     配置哲学（三层服务管理）：
--
--       Layer 1 — 系统层（systemctl enable）
--         开机即跑，与用户登录无关
--         例：sddm, bluetooth, polkit, wpa_supplicant
--
--       Layer 2 — 用户 systemd 层（hyprland-session.target）
--         后台守护进程：崩溃自动重启，不受 Hyprland reload 影响
--         本文件通过 systemctl start/stop 控制 target 的启停
--         所有 PartOf 该 target 的服务会同步启停
--         例：fcitx5, cliphist, lianwall, hysp, stalk-hypr, hypr-event-daemon
--
--       Layer 3 — Hyprland exec 层（hyprland.start 事件）
--         GUI 应用：需要 Wayland 环境，跟随 Hyprland 同生共死
--         一次性命令（mkdir, setcursor）也放在这里
--         例：qs, kanshi, mihomo-party, lianclaw, tuxedo-tray
--


-- ============================================================
-- 导入 Wayland 环境变量到 systemd user session
--     这是 Layer 2 服务能正常工作的前提
--     systemd user 服务需要这些变量才能与 Wayland 通信
-- ============================================================

local screenshotDir = "$HOME/Pictures/Screenshots"

local importEnv = "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE DISPLAY GTK_IM_MODULE QT_IM_MODULE XMODIFIERS"


-- ============================================================
-- Hyprland 启动事件
--     执行顺序有严格依赖，不要随意打乱
-- ============================================================

hl.on("hyprland.start", function()

    -- 1. 导入环境变量到 systemd
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. importEnv)
    hl.exec_cmd("systemctl --user import-environment " .. importEnv)

    -- 2. 启动用户会话 target（Layer 2 后台守护进程）
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- 3. Quickshell 必须最先启动
    --    托盘 clients 依赖它的 StatusNotifierWatcher 才能正常显示图标
    hl.exec_cmd("qs")

    -- 4. 一次性命令
    hl.exec_cmd("mkdir -p " .. screenshotDir)

    -- 5. Layer 3 GUI 应用
    hl.exec_cmd("kanshi")                               -- 多显示器自动配置
    hl.exec_cmd("mihomo-party")                         -- 代理客户端
    hl.exec_cmd("/home/Sakurine/.local/bin/lianclaw")   -- 自研工具
    hl.exec_cmd("tuxedo-control-center --tray")         -- TUXEDO 硬件控制托盘
end)


-- ============================================================
-- Hyprland 关闭事件
--     停止 target 后 systemd 会自动清理所有 PartOf 的子服务
--     Layer 3 GUI 应用会跟随 Hyprland 进程 natural death
-- ============================================================

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)
