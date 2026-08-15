return {
    {
        "numToStr/Comment.nvim",
        event = "VeryLazy",
        config = function()
            require("Comment").setup({
                -- 不启用默认 gcc，改走 <leader>cc
                mappings = {
                    basic = false,
                    extra = false,
                },
                pre_hook = function(ctx)
                    if vim.bo.filetype == "json" or vim.bo.filetype == "jsonc" then
                        vim.bo.commentstring = "//%s"
                    end
                    return require("Comment.utils").create_pre_hook()(ctx)
                end,
            })
        end,
    },
}
