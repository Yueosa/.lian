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
        gaps_out = 6,                       -- 屏幕外边距（四周留白；8px rail 吃掉一部分边宽，故从 12 收到 6）
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

        -- 窗口投影：小范围低透明，只留层次感不要辉光
        shadow = {
            enabled = true,
            range = 8,                      -- 扩散范围（原 15，大了就是辉光）
            render_power = 4,              -- 强度（越大阴影越集中，越小越散）
            color = "rgba(b19cd922)",       -- 淡紫 13% 不透明（原 33 = 20%）
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
-- 动画曲线 — M3 expressive
--     与 qsl 共用同族曲线，窗口和 shell 面板手感一致
--     spatial 系：第二个控制点 y > 1，到位后过冲回弹（黏滞感来源）
--     accel：离场专用，不看过冲（窗口关到一半弹回来会很怪）
-- ============================================================

-- 位移默认：0.38, 1.21, 0.22, 1
hl.curve("spatial", {
    type = "bezier",
    points = {
        { 0.38, 1.21 },
        { 0.22, 1 },
    },
})

-- 离场加速：0.3, 0, 0.8, 0.15
hl.curve("accel", {
    type = "bezier",
    points = {
        { 0.3, 0 },
        { 0.8, 0.15 },
    },
})


-- ============================================================
-- 窗口动画
--     speed 换算：duration ≈ speed × 100ms（speed 越大越慢）
-- ============================================================

-- 窗口打开：滑入 + 过冲回弹（≈500ms）
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "spatial", style = "slide" })
-- 窗口关闭：加速离场，不拖沓（≈200ms，当前手感已确认）
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "accel", style = "slide" })
-- 窗口移动：过冲回弹（≈400ms）
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "spatial" })
-- 工作区切换：过冲降到 1.21、时长收到 ≈500ms
-- 过冲大 + 长尾 = 内容到动画末期才静止，眼睛迟迟无法聚焦读内容
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "spatial", style = "slidefade" })
