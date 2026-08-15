-- 打开 Python 文件时：从文件所在目录逐级往上找 .venv
-- 找到就交给 venv-selector 激活（pyright 才会看见依赖）
-- <leader>vs 仍可手动重选

local function find_dot_venv_python(start_dir)
    local home = vim.fn.expand("~")
    local dir = start_dir
    local seen = {}

    while dir and dir ~= "" and not seen[dir] do
        seen[dir] = true
        if dir == home then
            break
        end

        local python = dir .. "/.venv/bin/python"
        if vim.fn.executable(python) == 1 then
            return python
        end

        local parent = vim.fn.fnamemodify(dir, ":h")
        if parent == dir then
            break
        end
        dir = parent
    end
end

local function activate_nearest_venv(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    if vim.bo[bufnr].filetype ~= "python" or vim.bo[bufnr].buftype ~= "" then
        return
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return
    end

    local python = find_dot_venv_python(vim.fn.fnamemodify(name, ":h"))
    if not python then
        return
    end

    local vs = require("venv-selector")
    if vs.python() == python then
        return
    end

    vs.activate_from_path(python, "venv")
end

return {
    {
        "linux-cultist/venv-selector.nvim",
        dependencies = {
            "neovim/nvim-lspconfig",
            "nvim-telescope/telescope.nvim",
        },
        event = "VeryLazy",
        config = function()
            require("venv-selector").setup({
                options = {
                    notify_user_on_venv_activation = false,
                    override_notify = false,
                },
            })

            vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
                pattern = "python",
                callback = function(args)
                    vim.defer_fn(function()
                        activate_nearest_venv(args.buf)
                    end, 50)
                end,
            })
        end,
    },
}
