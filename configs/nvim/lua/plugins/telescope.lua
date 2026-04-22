return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        opts = {
            defaults = {
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--hidden",
                    "--glob=!**/.git/*",
                    "--glob=!**/node_modules/*",
                    "--glob=!**/vendor/*",
                    "--glob=!**/dist/*",

                    "--glob=!**/package-lock.json",
                    "--glob=!**/yarn.lock",
                    "--glob=!**/pnpm-lock.yaml",
                    "--glob=!**/bun.lockb",
                    "--glob=!**/composer.lock",
                    "--glob=!**/Cargo.lock",
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
