-- 设置 Leader 键
vim.g.mapleader = " "

-- 加载自定义色彩方案路径 (sakurine)
vim.opt.rtp:prepend(vim.fn.stdpath("config") .. "/sakurine")

-- 加载核心配置
require("core.options")
require("core.autocmds")
require("core.keymaps")

vim.cmd.colorscheme("sakurine")

-- 启动插件管理器
require("plugins")
