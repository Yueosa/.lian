-- Autocommands

-- 离开插入模式自动保存（仅 Markdown）
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*.md",
    callback = function()
        vim.cmd("silent write")
    end,
})
