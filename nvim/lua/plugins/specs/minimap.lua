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
