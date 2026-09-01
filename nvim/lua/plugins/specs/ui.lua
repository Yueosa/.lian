return {
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                update_focused_file = { enable = true },
                git = {
                    enable = true,
                    ignore = false,
                },
                filters = {
                    git_ignored = false,
                },
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")
                    -- 默认键（a 新建 / d 删除 / r 重命名等）只在树里生效
                    api.config.mappings.default_on_attach(bufnr)
                end,
            })
        end,
    },

    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        config = function()
            require("render-markdown").setup({ render_modes = { "n", "i", "v" } })
        end,
    },
}
