return {
  'dense-analysis/ale',
  config = function()
    local g = vim.g
    g.ale_linters = { python = { 'ruff' }, haskell = { 'hlint', 'hdevtools', 'hfmt' }, rust = { 'analyzer' } }
    g.ale_linters_ignore = { typescript = { 'deno' }, typescriptreact = { 'deno' } }
    g.ale_rust_rustfmt_options = '--edition 2018' -- this is not a perm solution
    g.ale_fixers = {
      python = { 'ruff', 'black', 'autopep8' },
      go = { 'gofmt', 'goimports' },
      terraform = { 'terraform' },
      javascript = { 'prettier' },
      css = { 'prettier' },
      typescript = { 'prettier' },
      typescriptreact = { 'prettier' },
      haskell = { 'ormolu' },
      rust = { 'rustfmt' },
      lua = { 'stylua' },
      sh = { 'shfmt' },
    }
    g.ale_hover_cursor = 0
    g.ale_echo_msg_format = '[%linter%] (%code%). %s [%severity%]'
    g.ale_echo_msg_error_str = '🚫'
    g.ale_echo_msg_warning_str = '⚡'
    g.ale_sh_shfmt_options = '-i 2'
    g.ale_python_mypy_options = '--ignore-missing-imports'
    g.ale_lua_stylua_options = '--column-width=120 --line-endings=Unix --indent-type=Spaces --indent-width=2'
      .. ' --quote-style=AutoPreferSingle --call-parentheses=None'
  end,
}
