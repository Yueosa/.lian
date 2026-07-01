-- 外观 / 主题配置
--     控制显示器输出、窗口外观、透明模糊阴影、动画曲线与速度


-- ============================================================
-- 核心外观
-- ============================================================

hl.config({

    -- 杂项
    misc = {
        disable_hyprland_logo = true,       -- 启动时不显示 Hyprland logo
        initial_workspace_tracking = 0,     -- 初始工作区跟踪从 0 开始
    },

    -- 通用设置
    general = {
        gaps_in = 6,                        -- 窗口内边距
        gaps_out = 12,                      -- 屏幕外边距（四周留白）
        border_size = 3,                    -- 边框宽度 3px
        col = {
            -- 活动窗口边框：粉→蓝→白 45° 渐变
            active_border = {
                colors = {
                    "rgba(ffb7c5ee)",       -- 粉色
                    "rgba(87cefaee)",       -- 天蓝
                    "rgba(ffffffee)",       -- 白色
                },
                angle = 45,
            },
            -- 非活动窗口边框：半透明蓝色
            inactive_border = "rgba(87cefa55)",
        },
        layout = "dwindle",                 -- 默认布局：dwindle
    },

    -- scrolling 布局专属参数
    --     仅当通过 Super+S 切换到 scrolling 布局时生效
    scrolling = {
        direction = "right",               -- 新窗口向右堆叠
        column_width = 0.8,                -- 每列宽度占屏幕 80%
        follow_focus = true,               -- 焦点切换时自动滚动到目标列
        follow_min_visible = 0.4,          -- 目标列至少可见 40% 才不触发滚动
        fullscreen_on_one_column = true,   -- 单列时全屏显示
    },

    -- 装饰
    decoration = {
        rounding = 12,                      -- 圆角半径 12px
        active_opacity = 0.9,              -- 活动窗口透明度（1.0 为不透明）
        inactive_opacity = 0.8,            -- 非活动窗口透明度

        -- 窗口投影
        shadow = {
            enabled = true,
            range = 15,                     -- 阴影扩散范围
            render_power = 3,              -- 阴影强度（越大越深）
            color = "rgba(b19cd933)",       -- 紫色调阴影（b19cd9 = 淡紫，33 = 20% 不透明度）
        },

        -- 毛玻璃模糊
        blur = {
            enabled = true,
            size = 8,                       -- 模糊半径
            passes = 2,                     -- 模糊迭代次数（越大越细腻但越耗性能）
            new_optimizations = true,       -- 开启新版模糊优化
        },
    },

    -- 动画总开关
    animations = {
        enabled = true,
    },
})


-- ============================================================
-- 动画曲线 — fastIn
--     自定义贝塞尔曲线：快入慢停，干脆利落不拖沓
--     QML 对应：cubic-bezier(0.16, 1, 0.3, 1)
--     记录于 FEATURES.md 设计令牌，全局统一使用
-- ============================================================

hl.curve("fastIn", {
    type = "bezier",
    points = {
        { 0.16, 1 },
        { 0.3, 1 },
    },
})


-- ============================================================
-- 窗口动画
--     全部使用 fastIn 曲线，确保全局动画节奏统一
--     speed 越高越快（大致换算：duration ≈ 60/speed * 10 ms）
-- ============================================================

-- 窗口打开：滑入
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "fastIn", style = "slide" })
-- 窗口关闭：滑出
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "fastIn", style = "slide" })
-- 窗口移动：无样式（瞬移 + 缓动）
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "fastIn" })
-- 工作区切换：滑 + 淡入
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "fastIn", style = "slidefade" })
