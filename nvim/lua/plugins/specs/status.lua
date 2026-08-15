-- 底部状态栏 + 顶部 buffer 标签
-- 快捷键之后再写：<leader><Left/Right> 切换，<leader><Up> 关闭

return {
    {
        "nvim-lualine/lualine.nvim",
        event = "VimEnter",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = {
                    -- auto：跟着 sakurine 的高亮走，不另套主题
                    theme = "auto",
                    globalstatus = true,
                    component_separators = { left = "", right = "" },
                    section_separators = { left = "", right = "" },
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "encoding", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            })
        end,
    },

    {
        "akinsho/bufferline.nvim",
        event = "VimEnter",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("bufferline").setup({
                options = {
                    mode = "buffers",
                    diagnostics = "nvim_lsp",
                    always_show_bufferline = true,
                    show_buffer_close_icons = true,
                    separator_style = "thin",
                    offsets = {
                        {
                            filetype = "NvimTree",
                            text = "文件树",
                            highlight = "Directory",
                            text_align = "left",
                        },
                    },
                },
            })
        end,
    },
}
