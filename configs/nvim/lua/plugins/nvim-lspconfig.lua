return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            inlay_hints = { enabled = false },
            servers = {
                laravel_lsp = {
                    cmd = { "laravel-lsp" },
                    filetypes = { "php", "blade" },
                    root_markers = { "artisan", "composer.json", ".git" },
                },
            },
        },
    },
    {
        "pmizio/typescript-tools.nvim",
        dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
        opts = {},
    },
}
