return {
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
            { "nvim-lua/plenary.nvim" },
        },
        opts = {
            window = {
                layout = "vertical",
                width = 0.4,
            },
            auto_insert_mode = true,
        },
        config = function(_, opts)
            if vim.fn.executable("node") == 0 then
                vim.notify(
                    "Copilot Chat 需要 Node.js（命令 node）。请先安装 nodejs，然后在 nvim 里运行 :Copilot auth 或 :Copilot setup。",
                    vim.log.levels.WARN
                )
            end

            local chat = require("CopilotChat")
            chat.setup(opts)

            -- AI 相关快捷键统一用 <leader>a 前缀
            vim.keymap.set("n", "<leader>ac", "<cmd>CopilotChatToggle<cr>", { desc = "AI: Chat 开关" })
            vim.keymap.set("n", "<leader>ao", "<cmd>CopilotChatOpen<cr>", { desc = "AI: 打开 Chat" })
            vim.keymap.set("n", "<leader>ax", "<cmd>CopilotChatClose<cr>", { desc = "AI: 关闭 Chat" })
            vim.keymap.set("n", "<leader>ap", "<cmd>CopilotChatPrompts<cr>", { desc = "AI: Prompts" })
            vim.keymap.set("n", "<leader>am", "<cmd>CopilotChatModels<cr>", { desc = "AI: Models" })

            vim.keymap.set("n", "<leader>aa", function()
                local input = vim.fn.input("CopilotChat> ")
                if input == nil or vim.trim(input) == "" then
                    return
                end
                chat.ask(input)
            end, { desc = "AI: 询问（输入）" })

            vim.keymap.set("v", "<leader>aa", function()
                local input = vim.fn.input("CopilotChat(visual)> ")
                if input == nil or vim.trim(input) == "" then
                    return
                end
                chat.ask(input, { selection = "visual" })
            end, { desc = "AI: 询问（选中）" })
        end,
    },
}
