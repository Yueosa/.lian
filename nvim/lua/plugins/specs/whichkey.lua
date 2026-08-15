return {
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")
            wk.setup({
                preset = "modern",
                delay = 300,
                win = { border = "rounded" },
            })

            wk.add({
                { "<leader>w", desc = "开关文件树" },
                { "<leader>e", desc = "文件树/编辑区" },
                { "<leader>f", group = "搜索" },
                { "<leader>d", group = "诊断" },
                { "<leader>k", desc = "查看文档" },
                { "<leader>c", group = "注释" },
                { "<leader>v", group = "Python 环境" },
                { "<leader><Left>", desc = "上一个标签" },
                { "<leader><Right>", desc = "下一个标签" },
                { "<leader><Up>", desc = "关闭当前标签" },
            })
        end,
    },
}
