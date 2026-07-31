-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.scrolloff = 40
vim.opt.termguicolors = true

local apple_interface_style = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
vim.opt.background = vim.v.shell_error == 0 and apple_interface_style:match("Dark") and "dark" or "light"

vim.wo.wrap = false
vim.wo.linebreak = true
vim.wo.list = false

vim.g.neovide_cursor_trail_size = 1.0
vim.g.neovide_cursor_animation_length = 0.04

vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    callback = function()
        vim.opt_local.spell = false
    end,
})

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    pattern = { ".env", ".env.*", "*.env", "*.env.*" },
    callback = function()
        vim.opt_local.backup = false
        vim.opt_local.writebackup = false
        vim.opt_local.swapfile = false
        vim.opt_local.undofile = false
    end,
})

pcall(function()
    vim.fn.serverstart(vim.fn.stdpath("run") .. "/pi-" .. vim.fn.getpid() .. ".sock")
end)
