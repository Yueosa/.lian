-- 自定义键尽量都走 <leader>（空格），不抢 Vim 原生。
-- 例外：文件树内部的 a/d/r（只在树里生效）；补全弹出后的 Tab。

local keymap = vim.keymap.set

-- ─────────────────────────────────────────────
-- 文件树
-- ─────────────────────────────────────────────
keymap("n", "<leader>w", "<cmd>NvimTreeToggle<CR>", { desc = "开关文件树" })
keymap("n", "<leader>e", function()
    local api = require("nvim-tree.api")
    if vim.bo.filetype == "NvimTree" then
        vim.cmd("wincmd p")
        return
    end
    local ok, visible = pcall(function()
        return api.tree.is_visible and api.tree.is_visible() or false
    end)
    if ok and visible then
        api.tree.focus()
    else
        api.tree.open()
        api.tree.focus()
    end
end, { desc = "文件树/编辑区切换" })

-- ─────────────────────────────────────────────
-- 搜索（先留着，which-key 里能看见）
-- ─────────────────────────────────────────────
keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "按文件名搜索" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "按内容搜索" })

-- ─────────────────────────────────────────────
-- 文档 / 诊断
-- ─────────────────────────────────────────────
keymap("n", "<leader>k", function()
    vim.lsp.buf.hover({ border = "rounded", max_width = 80 })
end, { desc = "查看文档" })

keymap("n", "<leader>dd", function()
    vim.diagnostic.open_float({ border = "rounded" })
end, { desc = "当前行诊断" })

-- ─────────────────────────────────────────────
-- Buffer 标签
-- ─────────────────────────────────────────────
keymap("n", "<leader><Left>", "<cmd>BufferLineCyclePrev<CR>", { desc = "上一个标签" })
keymap("n", "<leader><Right>", "<cmd>BufferLineCycleNext<CR>", { desc = "下一个标签" })
keymap("n", "<leader><Up>", function()
    if vim.bo.filetype == "NvimTree" then
        return
    end
    if vim.bo.modified then
        vim.notify("有未保存的修改，先 :w 再关", vim.log.levels.WARN)
        return
    end

    local current = vim.api.nvim_get_current_buf()
    local listed = vim.fn.getbufinfo({ buflisted = 1 })
    if #listed <= 1 then
        vim.cmd("bdelete")
        vim.cmd("enew")
        return
    end

    vim.cmd("BufferLineCyclePrev")
    vim.cmd("bdelete " .. current)
end, { desc = "关闭当前标签" })

-- ─────────────────────────────────────────────
-- 注释（不绑 gcc，避免和「尽量走 leader」不一致）
-- ─────────────────────────────────────────────
keymap("n", "<leader>cc", function()
    require("Comment.api").toggle.linewise.current()
end, { desc = "注释当前行" })
keymap("x", "<leader>cc", function()
    local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
    vim.api.nvim_feedkeys(esc, "nx", false)
    require("Comment.api").toggle.linewise(vim.fn.visualmode())
end, { desc = "注释选中" })

-- ─────────────────────────────────────────────
-- Python 环境：自动找 .venv；这个是手动重选
-- ─────────────────────────────────────────────
keymap("n", "<leader>vs", "<cmd>VenvSelect<cr>", { desc = "手动选择虚拟环境" })
