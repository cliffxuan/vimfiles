-- Minimal init file for running tests
-- This avoids loading the full nvim config which might have missing dependencies

-- Set up the Lua path to find plenary
vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/plenary.nvim')

-- Basic vim settings needed for tests
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '