return {
  'Julian/lean.nvim',
  event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },

  dependencies = {
    'neovim/nvim-lspconfig',
    'nvim-lua/plenary.nvim',
  },

  ft = 'lean',

  lsp = {
    init_options = {
      editDelay = 0,
      hasWidgets = true,
    },
  },
  ---@type lean.Config
  opts = {
    mappings = true,
  },
}
