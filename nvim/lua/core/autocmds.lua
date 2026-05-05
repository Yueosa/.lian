-- Autocommands

-- LSP 悬停弹窗圆角边框（放这里保证尽早加载）
local orig_hover = vim.lsp.handlers["textDocument/hover"]
vim.lsp.handlers["textDocument/hover"] = function(_, result, ctx, config)
    config = vim.tbl_deep_extend("force", config or {}, {
        border = "rounded",
        max_width = 80,
    })
    return orig_hover(_, result, ctx, config)
end

local orig_sig = vim.lsp.handlers["textDocument/signatureHelp"]
vim.lsp.handlers["textDocument/signatureHelp"] = function(_, result, ctx, config)
    config = vim.tbl_deep_extend("force", config or {}, {
        border = "rounded",
    })
    return orig_sig(_, result, ctx, config)
end

-- 离开插入模式自动保存（仅 Markdown）
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*.md",
    callback = function()
        vim.cmd("silent write")
    end,
})
