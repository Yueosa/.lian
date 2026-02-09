return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            local languages = { "rust", "lua", "vim", "vimdoc", "markdown", "markdown_inline" }

            if vim.fn.executable("tree-sitter") == 0 then
                vim.notify(
                    "nvim-treesitter(rewrite) 需要安装 tree-sitter-cli（命令 tree-sitter）。未检测到，已跳过自动安装 parser。",
                    vim.log.levels.WARN
                )
                return
            end

            require("nvim-treesitter").setup({
                install_dir = vim.fn.stdpath("data") .. "/site",
            })

            local parser_dir = require("nvim-treesitter.config").get_install_dir("parser")
            local missing = {}
            for _, lang in ipairs(languages) do
                local parser_path = vim.fs.joinpath(parser_dir, lang .. ".so")
                if not vim.uv.fs_stat(parser_path) then
                    table.insert(missing, lang)
                end
            end
            if #missing > 0 then
                require("nvim-treesitter").install(missing):wait(300000)
            end

            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "rust", "lua", "vim", "vimdoc", "markdown" },
                callback = function()
                    pcall(vim.treesitter.start)
                end,
            })

            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "rust", "lua", "vim", "markdown" },
                callback = function()
                    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end,
            })
        end,
    },
}
