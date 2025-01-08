return {
  'nvim-telescope/telescope.nvim',
  dependencies = { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  config = function()
    local actions = require 'telescope.actions'
    local action_layout = require 'telescope.actions.layout'
    require('telescope').setup {
      defaults = {
        mappings = {
          n = {
            ['<C-q>'] = actions.send_to_qflist,
            ['<C-w>'] = actions.send_selected_to_qflist,
            ['<M-p>'] = action_layout.toggle_preview,
          },
          i = {
            ['<C-j>'] = actions.move_selection_next,
            ['<C-k>'] = actions.move_selection_previous,
            ['<C-q>'] = actions.send_to_qflist,
            ['<C-w>'] = actions.send_selected_to_qflist,
            ['<M-p>'] = action_layout.toggle_preview,
          },
        },
        layout_config = {
          horizontal = { height = 0.95, width = 0.95, preview_width = 0.6 },
        },
      },
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = 'smart_case',
        },
      },
      pickers = {
        buffers = {
          mappings = {
            n = { ['dd'] = actions.delete_buffer },
          },
        },
      },
    }
    require('telescope').load_extension 'fzf'
    vim.cmd 'autocmd User TelescopePreviewerLoaded setlocal number'
  end,
}
