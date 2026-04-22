return {
    {
        "nvim-neo-tree/neo-tree.nvim",
        config = function()
            require("neo-tree").setup({
                filesystem = {
                    follow_current_file = {
                        enabled = true,
                        leave_dirs_open = true,
                    },
                    filtered_items = {
                        always_show_by_pattern = {
                            ".env*",
                        },
                        show_hidden_count = false,
                    },
                },
                default_component_configs = {
                    modified = {
                        symbol = " ",
                        highlight = "NeoTreeModified",
                    },
                    git_status = {
                        symbols = {
                            added = "",
                            deleted = "",
                            modified = "",
                            renamed = "",
                            untracked = "",
                            ignored = "",
                            unstaged = "",
                            staged = "",
                            conflict = "",
                        },
                    },
                },
                window = {
                    position = "right",
                    mappings = {
                        ["l"] = "open",
                        ["h"] = "close_node",
                        ["<space>"] = "none",
                        ["P"] = { "toggle_preview", config = { use_float = false } },
                        ["<BS>"] = function(state)
                            local cwd = vim.fn.getcwd()
                            if state.path == cwd then
                                print("Cannot go up, already at root directory.")
                            else
                                require("neo-tree.sources.filesystem").navigate_up(state)
                            end
                        end,
                    },
                },
            })
        end,
    },
}
