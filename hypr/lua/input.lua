-- 输入设备配置
--     键盘布局、焦点跟随、触控板行为
--     部分值是默认值，但显式声明防止未来默认变更


hl.config({
    input = {
        -- 键盘布局：美式英语
        kb_layout = "us",

        -- 焦点跟随鼠标（鼠标移到哪个窗口，焦点就切过去）
        follow_mouse = 1,

        -- 触控板
        touchpad = {
            -- 关闭自然滚动（传统 Linux 滚动方向：向下滚 = 内容上移）
            natural_scroll = false,
        },
    },
})
