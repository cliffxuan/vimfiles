return {
  'jackMort/ChatGPT.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
    'nvim-lua/plenary.nvim',
    'folke/trouble.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('chatgpt').setup {
      api_key_cmd = 'openaikey',
    }
    require('which-key').add {
      { '<leader>n', group = 'ChatGPT' },
      { '<leader>np', '<cmd>ChatGPTActAs<CR>', desc = 'Act As...', mode = { 'n', 'v' } },
      { '<leader>nn', '<cmd>ChatGPT<CR>', desc = 'ChatGPT' },
      { '<leader>ne', '<cmd>ChatGPTEditWithInstruction<CR>', desc = 'Edit with instruction', mode = { 'n', 'v' } },
      { '<leader>ng', '<cmd>ChatGPTRun grammar_correction<CR>', desc = 'Grammar Correction', mode = { 'n', 'v' } },
      { '<leader>nt', '<cmd>ChatGPTRun translate<CR>', desc = 'Translate', mode = { 'n', 'v' } },
      { '<leader>nk', '<cmd>ChatGPTRun keywords<CR>', desc = 'Keywords', mode = { 'n', 'v' } },
      { '<leader>nd', '<cmd>ChatGPTRun docstring<CR>', desc = 'Docstring', mode = { 'n', 'v' } },
      { '<leader>na', '<cmd>ChatGPTRun add_tests<CR>', desc = 'Add Tests [add_tests]', mode = { 'n', 'v' } },
      { '<leader>no', '<cmd>ChatGPTRun optimize_code<CR>', desc = 'Optimize Code', mode = { 'n', 'v' } },
      { '<leader>ns', '<cmd>ChatGPTRun summarize<CR>', desc = 'Summarize', mode = { 'n', 'v' } },
      { '<leader>nf', '<cmd>ChatGPTRun fix_bugs<CR>', desc = 'Fix Bugs', mode = { 'n', 'v' } },
      { '<leader>nx', '<cmd>ChatGPTRun explain_code<CR>', desc = 'Explain Code', mode = { 'n', 'v' } },
      { '<leader>nr', '<cmd>ChatGPTRun roxygen_edit<CR>', desc = 'Roxygen Edit', mode = { 'n', 'v' } },
      { '<leader>nl', '<cmd>ChatGPTRun code_readability_analysis<CR>', desc = 'Code Readability Analysis', mode = { 'n', 'v' } },
    }
  end,
}
