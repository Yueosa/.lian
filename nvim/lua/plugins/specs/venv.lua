return {
    {
        "linux-cultist/venv-selector.nvim",
        dependencies = {
            "neovim/nvim-lspconfig",
            "nvim-telescope/telescope.nvim",
        },
        event = "VeryLazy",
        config = true,
        keys = {
            { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "选择虚拟环境" },
        },
    },
}
