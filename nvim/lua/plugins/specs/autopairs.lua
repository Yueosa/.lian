return {
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            local npairs = require("nvim-autopairs")
            npairs.setup({})

            -- 与 nvim-cmp 结合：确认补全后自动补全括号
            local ok_cmp, cmp = pcall(require, "cmp")
            if ok_cmp then
                local ok_apcmp, apcmp = pcall(require, "nvim-autopairs.completion.cmp")
                if ok_apcmp then
                    cmp.event:on("confirm_done", apcmp.on_confirm_done())
                end
            end
        end,
    },
}
