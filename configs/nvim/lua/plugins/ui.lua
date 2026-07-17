local function set_tokyonight_terminal(style)
    local colors = style == "day"
            and {
                "#e9e9ed",
                "#f52a65",
                "#587539",
                "#8c6c3e",
                "#2e7de9",
                "#9854f1",
                "#007197",
                "#6172b0",
                "#a1a6c5",
                "#f52a65",
                "#587539",
                "#8c6c3e",
                "#2e7de9",
                "#9854f1",
                "#007197",
                "#3760bf",
            }
        or {
            "#15161e",
            "#f7768e",
            "#9ece6a",
            "#e0af68",
            "#7aa2f7",
            "#bb9af7",
            "#7dcfff",
            "#a9b1d6",
            "#414868",
            "#f7768e",
            "#9ece6a",
            "#e0af68",
            "#7aa2f7",
            "#bb9af7",
            "#7dcfff",
            "#c0caf5",
        }

    for index, color in ipairs(colors) do
        vim.g["terminal_color_" .. (index - 1)] = color
    end
end

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
            set_tokyonight_terminal("storm")
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
                set_tokyonight_terminal("storm")
            end,
            set_light_mode = function()
                vim.api.nvim_set_option_value("background", "light", {})
                vim.cmd("colorscheme tokyonight-day")
                set_tokyonight_terminal("day")
            end,
            update_interval = 3000,
            fallback = "dark",
        },
    },
}
