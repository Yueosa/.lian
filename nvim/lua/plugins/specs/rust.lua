return {
    {
        "mrcjkb/rustaceanvim",
        version = "^5",
        lazy = false,
        config = function()
            vim.g.rustaceanvim = {
                server = {
                    on_attach = function(_, bufnr)
                        vim.keymap.set(
                            "n",
                            "<leader>ca",
                            function() vim.cmd.RustLsp("codeAction") end,
                            { buffer = bufnr, desc = "代码操作" }
                        )
                    end,
                    default_settings = {
                        ["rust-analyzer"] = {
                            cargo = {
                                allFeatures = true,
                            },
                            procMacro = {
                                enable = true,
                            },
                            checkOnSave = true,
                            check = { command = "clippy" },
                        },
                    },
                },
            }
        end,
    },
}
