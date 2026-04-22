return {
    {
        "adibhanna/laravel.nvim",
        ft = { "php", "blade" },
        dependencies = { "folke/snacks.nvim" },
        config = function()
            require("laravel").setup({
                notifications = false,
                debug = false,
                keymaps = false,
            })
        end,
    },
}
