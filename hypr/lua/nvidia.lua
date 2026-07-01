-- NVIDIA 显卡兼容配置
--     这些设置解决 NVIDIA 专有驱动在 Wayland 下的常见问题


-- ============================================================
-- 环境变量
--     子进程（包括 systemd user services 和所有 GUI 应用）会继承这些变量
-- ============================================================

-- VA-API 硬件视频加速使用 NVIDIA 驱动
hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- GBM 缓冲区管理后端（Wayland + NVIDIA 必需）
hl.env("GBM_BACKEND", "nvidia-drm")
-- OpenGL 渲染使用 NVIDIA GLX
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- NVIDIA 直接渲染模式
hl.env("NVD_BACKEND", "direct")

-- 禁用硬件光标渲染（NVIDIA 常见 bug：光标残留/花屏）
--     下面 hl.config 里也关了一次，那条只管 Hyprland
--     这个 env 变量同时影响其他 wlroots 兼容应用
hl.env("WLR_NO_HARDWARE_CURSORS", "1")


-- ============================================================
-- Hyprland 光标配置
--     与上面的 WLR_NO_HARDWARE_CURSORS 功能相同，但这是 Hyprland 原生设置
--     两边都保留是安全的，不会冲突
-- ============================================================

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
})
