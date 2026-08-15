-- 同词高亮：光标停在某个标识符上，文件里相同的词一起亮

return {
    {
        "RRethy/vim-illuminate",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("illuminate").configure({
                delay = 200,
                large_file_cutoff = 2000,
                filetypes_denylist = {
                    "NvimTree",
                    "lazy",
                    "mason",
                    "TelescopePrompt",
                },
            })
        end,
    },
}
