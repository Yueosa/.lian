-- 缩进竖线 + 彩虹括号，颜色跟 sakurine 调色板走

local sakurine_rainbow = {
    "SakurineRainbowRed",
    "SakurineRainbowOrange",
    "SakurineRainbowCyan",
    "SakurineRainbowGreen",
    "SakurineRainbowPurple",
    "SakurineRainbowPink",
}

local function set_rainbow_hl()
    vim.api.nvim_set_hl(0, "SakurineRainbowRed", { fg = "#F38BA8" })
    vim.api.nvim_set_hl(0, "SakurineRainbowOrange", { fg = "#E1B4CE" })
    vim.api.nvim_set_hl(0, "SakurineRainbowCyan", { fg = "#5BCEFA" })
    vim.api.nvim_set_hl(0, "SakurineRainbowGreen", { fg = "#8BB8E9" })
    vim.api.nvim_set_hl(0, "SakurineRainbowPurple", { fg = "#AB8CAE" })
    vim.api.nvim_set_hl(0, "SakurineRainbowPink", { fg = "#F5A9B8" })
end

return {
    {
        "lukas-reineke/indent-blankline.nvim",
        event = { "BufReadPost", "BufNewFile" },
        main = "ibl",
        config = function()
            local hooks = require("ibl.hooks")
            hooks.register(hooks.type.HIGHLIGHT_SETUP, set_rainbow_hl)

            require("ibl").setup({
                indent = {
                    char = "│",
                    highlight = sakurine_rainbow,
                },
                scope = {
                    enabled = true,
                },
                exclude = {
                    filetypes = {
                        "help",
                        "NvimTree",
                        "lazy",
                        "mason",
                        "qf",
                    },
                },
            })
        end,
    },

    {
        "HiPhish/rainbow-delimiters.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            set_rainbow_hl()
            vim.api.nvim_create_autocmd("ColorScheme", {
                callback = set_rainbow_hl,
            })

            local rainbow_delimiters = require("rainbow-delimiters")
            vim.g.rainbow_delimiters = {
                strategy = {
                    [""] = rainbow_delimiters.strategy["global"],
                },
                query = {
                    [""] = "rainbow-delimiters",
                },
                highlight = sakurine_rainbow,
            }
        end,
    },
}
