return {
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                update_focused_file = { enable = true },
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")

                    -- 保留默认映射
                    api.config.mappings.default_on_attach(bufnr)

                    -- 在文件树中用 v 竖分屏打开（避免进入可视模式）
                    vim.keymap.set(
                        "n",
                        "v",
                        api.node.open.vertical,
                        { buffer = bufnr, noremap = true, silent = true, nowait = true, desc = "竖分屏打开" }
                    )
                end,
            })
            vim.keymap.set("n", "<leader>w", ":NvimTreeToggle<CR>", { desc = "文件树" })

            -- 在文件树与编辑窗口之间切换
            vim.keymap.set("n", "<leader>e", function()
                local api = require("nvim-tree.api")
                if vim.bo.filetype == "NvimTree" then
                    vim.cmd("wincmd p")
                    return
                end

                local ok_visible, visible = pcall(function()
                    return api.tree.is_visible and api.tree.is_visible() or false
                end)
                if ok_visible and visible then
                    api.tree.focus()
                else
                    api.tree.open()
                    api.tree.focus()
                end
            end, { desc = "文件树/编辑区切换" })
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
