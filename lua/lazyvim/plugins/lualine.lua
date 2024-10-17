return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'folke/tokyonight.nvim' },
    config = function()
      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = 'tokyonight',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = { {
            'mode',
            fmt = function(str)
              return str:sub(1, 1)
            end,
          } },
          lualine_b = {
            'branch',
            'diff',
          },
          lualine_c = {
            'filename',
            {
              'diagnostics',
              -- Table of diagnostic sources, available sources are:
              --   'nvim_lsp', 'nvim_diagnostic', 'nvim_workspace_diagnostic', 'coc', 'ale', 'vim_lsp'.
              -- or a function that returns a table as such:
              --   { error=error_cnt, warn=warn_cnt, info=info_cnt, hint=hint_cnt }
              sources = { 'nvim_diagnostic', 'ale' },
              -- Displays diagnostics for the defined severity types
              sections = { 'error', 'warn', 'info', 'hint' },
              diagnostics_color = {
                -- Same values as the general color option can be used here.
                error = 'DiagnosticError', -- Changes diagnostics' error color.
                warn = 'DiagnosticWarn', -- Changes diagnostics' warn color.
                info = 'DiagnosticInfo', -- Changes diagnostics' info color.
                hint = 'DiagnosticHint', -- Changes diagnostics' hint color.
              },
              symbols = { error = 'E', warn = 'W', info = 'I', hint = 'H' },
              colored = true, -- Displays diagnostics status in color if set to true.
              update_in_insert = false, -- Update diagnostics in insert mode.
              always_visible = false, -- Show diagnostics even if there are none.
            },
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { 'filename' },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
      }
    end,
  },
}
