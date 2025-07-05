return {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.install').prefer_git = true
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'c', 'lua', 'vim', 'vimdoc', 'query', 'javascript', 'html', 'rust' },
        auto_install = true,
        sync_install = false,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        modules = {},
        ignore_install = {},
        fold = {
          enable = true,
        },
      }
      -- Set the foldmethod to use Treesitter
      vim.opt.foldmethod = 'expr'
      vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'
      -- Start with folds closed
      vim.opt.foldlevel = 0
    end,
  },
}
