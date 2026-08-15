-- 补全：默认边打边弹
-- Tab / Shift-Tab 只在菜单打开时切换（不绑方向键）
-- Ctrl+E 开关菜单（左手：左 Ctrl + E）
-- 回车：没选中条目就换行，选中了才采用

local function apply_cmp_hl()
    -- 比 sakurine 编辑区背景更深一点，再加粉色边框，才分得清
    vim.api.nvim_set_hl(0, "CmpNormal", { bg = "#2f2336", fg = "#cedaeb" })
    vim.api.nvim_set_hl(0, "CmpBorder", { fg = "#F5A9B8", bg = "#2f2336" })
    vim.api.nvim_set_hl(0, "CmpSel", { bg = "#60486d", fg = "#cedaeb", bold = true })
    vim.api.nvim_set_hl(0, "CmpDocNormal", { bg = "#2f2336", fg = "#cedaeb" })
    vim.api.nvim_set_hl(0, "CmpDocBorder", { fg = "#5BCEFA", bg = "#2f2336" })
end

return {
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "onsails/lspkind.nvim",
        },
        config = function()
            local cmp = require("cmp")
            local lspkind = require("lspkind")

            apply_cmp_hl()
            vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_cmp_hl })

            local function toggle_complete()
                if cmp.visible() then
                    cmp.abort()
                else
                    cmp.complete()
                end
            end

            cmp.setup({
                snippet = {
                    expand = function(args)
                        require("luasnip").lsp_expand(args.body)
                    end,
                },
                -- 不用 preset.insert：那套会绑上/下方向键
                mapping = {
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<C-e>"] = cmp.mapping(function()
                        toggle_complete()
                    end, { "i" }),
                    ["<CR>"] = cmp.mapping(function(fallback)
                        if cmp.visible() and cmp.get_selected_entry() then
                            cmp.confirm({ select = false })
                        else
                            fallback()
                        end
                    end, { "i" }),
                },
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                }, {
                    { name = "buffer" },
                    { name = "path" },
                }),
                formatting = {
                    format = lspkind.cmp_format({
                        mode = "symbol_text",
                        maxwidth = 40,
                        ellipsis_char = "...",
                    }),
                },
                window = {
                    completion = cmp.config.window.bordered({
                        border = "rounded",
                        winhighlight = "Normal:CmpNormal,FloatBorder:CmpBorder,CursorLine:CmpSel,Search:None",
                    }),
                    documentation = cmp.config.window.bordered({
                        border = "rounded",
                        winhighlight = "Normal:CmpDocNormal,FloatBorder:CmpDocBorder",
                    }),
                },
            })

            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = "path" },
                }, {
                    { name = "cmdline" },
                }),
            })

            cmp.setup.cmdline("/", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = "buffer" },
                },
            })
        end,
    },
}
