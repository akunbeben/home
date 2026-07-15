return {
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
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        opts = {
            style = "storm",
            transparent = true,
            styles = {
                comments = { italic = false },
                keywords = { italic = false },
            },
        },
        config = function(_, opts)
            require("tokyonight").setup(opts)
            vim.opt.termguicolors = true
            vim.cmd.colorscheme("tokyonight-storm")
            vim.g.terminal_color_0 = "#15161e"
            vim.g.terminal_color_1 = "#f7768e"
            vim.g.terminal_color_2 = "#9ece6a"
            vim.g.terminal_color_3 = "#e0af68"
            vim.g.terminal_color_4 = "#7aa2f7"
            vim.g.terminal_color_5 = "#bb9af7"
            vim.g.terminal_color_6 = "#7dcfff"
            vim.g.terminal_color_7 = "#a9b1d6"
            vim.g.terminal_color_8 = "#414868"
            vim.g.terminal_color_9 = "#f7768e"
            vim.g.terminal_color_10 = "#9ece6a"
            vim.g.terminal_color_11 = "#e0af68"
            vim.g.terminal_color_12 = "#7aa2f7"
            vim.g.terminal_color_13 = "#bb9af7"
            vim.g.terminal_color_14 = "#7dcfff"
            vim.g.terminal_color_15 = "#c0caf5"
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        optional = true,
        opts = function(_, opts)
            opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
                theme = "tokyonight",
            })
        end,
    },
    {
        "f-person/auto-dark-mode.nvim",
        opts = {
            set_dark_mode = function()
                vim.api.nvim_set_option_value("background", "dark", {})
                vim.cmd("colorscheme tokyonight-storm")
            end,
            set_light_mode = function()
                vim.api.nvim_set_option_value("background", "dark", {})
                vim.cmd("colorscheme tokyonight-storm")
            end,
            update_interval = 3000,
            fallback = "dark",
        },
    },
}
