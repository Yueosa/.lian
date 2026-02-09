local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

local specs = {}
vim.list_extend(specs, require("plugins.specs.git"))
vim.list_extend(specs, require("plugins.specs.ui"))
vim.list_extend(specs, require("plugins.specs.treesitter"))
vim.list_extend(specs, require("plugins.specs.lsp"))
vim.list_extend(specs, require("plugins.specs.rust"))
vim.list_extend(specs, require("plugins.specs.cmp"))
vim.list_extend(specs, require("plugins.specs.autopairs"))
vim.list_extend(specs, require("plugins.specs.whichkey"))
vim.list_extend(specs, require("plugins.specs.copilot"))
vim.list_extend(specs, require("plugins.specs.copilot_chat"))

require("lazy").setup(specs)
