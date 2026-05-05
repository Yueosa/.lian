return {
    {
        "numToStr/Comment.nvim",
        event = "VeryLazy",
        config = function()
            require("Comment").setup({
                pre_hook = function(ctx)
                    -- JSON/JSONC 用 // 注释
                    if vim.bo.filetype == "json" or vim.bo.filetype == "jsonc" then
                        vim.bo.commentstring = "//%s"
                    end
                    return require("Comment.utils").create_pre_hook()(ctx)
                end,
            })
        end,
    },
}
