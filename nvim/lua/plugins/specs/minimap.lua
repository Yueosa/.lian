-- 右侧代码缩略图：默认开着，不绑快捷键
-- 真要关：:Neominimap Toggle

return {
    {
        "Isrothy/neominimap.nvim",
        version = "v3.*.*",
        event = { "BufReadPost", "BufNewFile" },
        init = function()
            vim.g.neominimap = {
                auto_enable = true,
                -- float 会盖在编辑区上；split 占真实窗口，主编辑区自动让出右边
                layout = "split",
                split = {
                    minimap_width = 18,
                    fix_width = true,
                    direction = "right",
                    close_if_last_window = true,
                },
                exclude_filetypes = {
                    "help",
                    "NvimTree",
                    "lazy",
                    "mason",
                    "qf",
                    "fugitive",
                },
            }
        end,
    },
}
