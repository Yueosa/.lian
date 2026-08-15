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

-- 行首按左、行尾按右，跳到上一行/下一行（方向键 + hjkl）
opt.whichwrap:append("<>[]hl")

-- 补全菜单不预选第一项，避免回车变成「采用补全」而不是换行
opt.completeopt = { "menu", "menuone", "noselect" }
-- 补全菜单最多 10 条，避免盖住半个屏幕
opt.pumheight = 10

-- / 搜索：全小写忽略大小写，有大写则精确匹配
-- 当前文件用 / + n；全库文件名是 Space+ff，全库内容是 Space+fg
opt.ignorecase = true
opt.smartcase = true

-- 滚动时上下左右留空，光标不贴边
opt.scrolloff = 8
opt.sidescrolloff = 8

-- 左侧符号列常驻，避免 Git / 报错图标出现时整页跳动
opt.signcolumn = "yes"

-- 持久撤销（关文件再开还能 u）；不造 .swp
opt.undofile = true
opt.swapfile = false

-- 鼠标：点标签、点文件树、滚轮
opt.mouse = "a"

-- 停手 250ms 后刷新 Git 行标、同词高亮（默认 4000ms 太慢）
opt.updatetime = 250

-- 模式交给 lualine，不再在最底下重复 -- INSERT --
opt.showmode = false

-- 只标行尾空格 / Tab，不把每个空格都打点
opt.list = true
opt.listchars = {
    tab = "» ",
    trail = "·",
    extends = "›",
    precedes = "‹",
    nbsp = "␣",
}
