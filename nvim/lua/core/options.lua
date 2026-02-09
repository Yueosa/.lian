-- 快捷变量
local opt = vim.opt

-- 显示绝对行号
opt.number = true

-- 跟随终端颜色
opt.termguicolors = true

-- 分屏更符合直觉（vsplit 默认在右，split 默认在下）
opt.splitright = true
opt.splitbelow = true

-- 光标行高亮
opt.cursorline = true

-- 复制到系统剪贴板
opt.clipboard = "unnamedplus"

-- 一个 Tab 等于 4 个空格
opt.tabstop = 4
-- 插入模式下一个 Tab 的空格 
opt.softtabstop = 4
-- 每一次缩进的空格
opt.shiftwidth = 4
-- 将 Tab 转换为空格
opt.expandtab = true
-- 智能缩进
opt.smartindent = true

-- 离开插入模式自动保存
vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*.md",
    callback = function()
        vim.cmd("silent write")
    end,
})


