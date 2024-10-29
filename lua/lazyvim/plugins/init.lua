return {
  'ConradIrwin/vim-bracketed-paste',
  'easymotion/vim-easymotion',
  'editorconfig/editorconfig-vim',
  { 'junegunn/fzf', build = './install --bin' },
  'junegunn/fzf.vim',
  'majutsushi/tagbar',
  'Yggdroot/indentLine',
  'voldikss/vim-floaterm',
  'tpope/vim-abolish',
  'tpope/vim-endwise',
  'tpope/vim-fugitive',
  'tpope/vim-surround',
  'tpope/vim-repeat',
  'tpope/vim-commentary',
  'tpope/vim-unimpaired',
  'kana/vim-textobj-user',
  'terryma/vim-multiple-cursors',
  'mhinz/vim-signify',
  'rhysd/git-messenger.vim',
  {
    'folke/trouble.nvim',
    opts = {},
    cmd = 'Trouble',
  },
  {
    'sheerun/vim-polyglot',
    init = function()
      vim.g.polyglot_disabled = { 'python', 'markdown', 'autoindent' }
    end,
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 1000
    end,
    opts = {},
  },
  { 'folke/neodev.nvim', opts = {} },
  'williamboman/mason.nvim',
  -- theme
  'morhetz/gruvbox',
  'sickill/vim-monokai',
  'dracula/vim',
  'jnurmine/Zenburn',
  'haishanh/night-owl.vim',
  'ayu-theme/ayu-vim',
  'arcticicestudio/nord-vim',
  'junegunn/seoul256.vim',
  'altercation/vim-colors-solarized',
  'yuttie/hydrangea-vim',
  'NLKNguyen/papercolor-theme',
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        style = 'night',
        styles = {
          functions = {},
        },
        on_colors = function(colors)
          ---@diagnostic disable-next-line: inject-field
          colors.terminal_black = '#727169'
        end,
      }
    end,
  },
  'rebelot/kanagawa.nvim',
  'catppuccin/nvim',

  'SirVer/ultisnips',
  'neovim/nvim-lspconfig',
  'nvim-lua/plenary.nvim',
  -- language specific
  { 'begriffs/haskell-vim-now', ft = 'haskell' },
  { 'hashivim/vim-terraform', ft = 'terraform' },
  { 'OmniSharp/omnisharp-vim', ft = 'cs' },
  { 'Glench/Vim-Jinja2-Syntax', ft = 'jinja' },
  { 'jeetsukumaran/vim-pythonsense', ft = 'python' },
  { 'Vimjas/vim-python-pep8-indent', ft = 'python' },
  { 'simrat39/rust-tools.nvim', ft = 'rust' }, -- rust analyzer inlay
  { 'rust-lang/rust.vim', ft = 'rust' },
  { 'nvim-telescope/telescope.nvim', tag = '0.1.4' },
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {},
  },
}
