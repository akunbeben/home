local function set_opencode(mode)
    vim.api.nvim_set_option_value("background", mode, {})
    vim.cmd.colorscheme("opencode")
end

return {
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "opencode",
        },
    },
    {
        "christoomey/vim-tmux-navigator",
        cmd = {
            "TmuxNavigateLeft",
            "TmuxNavigateDown",
            "TmuxNavigateUp",
            "TmuxNavigateRight",
            "TmuxNavigatePrevious",
            "TmuxNavigatorProcessList",
        },
        keys = {
            { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
            { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
            { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
            { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
            { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
        },
    },
    {
        "folke/noice.nvim",
        opts = function(_, opts)
            opts.presets = {
                routes = {
                    filter = {
                        event = "notify",
                        find = "No information available",
                    },
                    opts = { skip = true },
                },
                command_palette = {
                    views = {
                        cmdline_popup = {
                            position = {
                                row = "50%",
                                col = "50%",
                            },
                            size = {
                                min_width = 70,
                                width = "auto",
                                height = "auto",
                            },
                        },
                    },
                },
            }
            opts.lsp.signature = {
                opts = { size = { max_height = 25 } },
            }
        end,
    },
    {
        "folke/flash.nvim",
        keys = {
            { "s", mode = { "n", "x", "o" }, false },
        },
    },
    {
        "f-person/auto-dark-mode.nvim",
        opts = {
            set_dark_mode = function()
                set_opencode("dark")
            end,
            set_light_mode = function()
                set_opencode("light")
            end,
            update_interval = 3000,
            fallback = "dark",
        },
    },
}
