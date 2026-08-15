return {
    {
        "mrcjkb/rustaceanvim",
        version = "^5",
        lazy = false,
        config = function()
            vim.g.rustaceanvim = {
                server = {
                    default_settings = {
                        ["rust-analyzer"] = {
                            cargo = {
                                allFeatures = true,
                            },
                            procMacro = {
                                enable = true,
                            },
                            checkOnSave = true,
                            check = { command = "check" },
                        },
                    },
                },
            }
        end,
    },
}
