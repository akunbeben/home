-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

local map = vim.keymap.set
map("n", "<A-r>", ":LspRestart<CR>", { noremap = true, silent = false })
map("n", "<A-e>", ":Neotree<CR>", { noremap = true, silent = true })

map("n", "<A-a>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<A-d>", "<cmd>bnext<cr>", { desc = "Next buffer" })

map("i", "<A-a>", "<Esc><cmd>bprevious<cr>", { desc = "Previous buffer" })
map("i", "<A-d>", "<Esc><cmd>bnext<cr>", { desc = "Next buffer" })

map("n", "<A-s>", ":w<CR>", { noremap = true, silent = true })
