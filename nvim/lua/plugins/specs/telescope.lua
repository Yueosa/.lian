return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        config = function()
            require("telescope").setup({
                defaults = require("telescope.themes").get_dropdown({
                    previewer = false,
                    layout_config = { width = 0.5 },
                    path_display = { "smart" },
                }),
            })
        end,
    },
}
