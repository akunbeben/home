return {
    {
        "mfussenegger/nvim-dap",
        opts = function(_, opts)
            require("config.go_debug_visual").setup()
            return opts
        end,
        keys = {
            {
                "<leader>dv",
                function()
                    require("config.go_debug_visual").toggle()
                end,
                desc = "Debug Visual Layer",
            },
        },
    },
}
