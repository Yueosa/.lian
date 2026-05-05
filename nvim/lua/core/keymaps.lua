-- 全局通用键位

-- 悬停文档（K 直接传 border 参数，兼容 Neovim 0.12）
vim.keymap.set("n", "K", function()
    vim.lsp.buf.hover({ border = "rounded", max_width = 80 })
end, { desc = "悬停文档" })

-- Telescope 模糊搜索
vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "搜索文件" })
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "搜索文本" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "切换 Buffer" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "搜索帮助" })

-- 诊断（查看 E/H/W 报错详情）
vim.keymap.set("n", "<leader>dd", function() vim.diagnostic.open_float({ border = "rounded" }) end, { desc = "诊断详情" })
vim.keymap.set("n", "]d", function() vim.diagnostic.goto_next({ float = false }) end, { desc = "下一处诊断" })
vim.keymap.set("n", "[d", function() vim.diagnostic.goto_prev({ float = false }) end, { desc = "上一处诊断" })
