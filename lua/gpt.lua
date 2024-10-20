local utils = require 'utils'
local Job = require 'plenary.job'

local create_buffer = function()
  vim.cmd 'botright new'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  return buf
end

local run_shell_command = function(shell_command, input, create_buffer_fn)
  create_buffer_fn = create_buffer_fn or create_buffer
  local buf = nil
  Job:new({
    command = 'sh',
    writer = input,
    interactive = input ~= nil,
    args = { '-c', shell_command },
    on_stdout = function(_, line)
      vim.schedule(function()
        if not buf then
          if line:gsub('^%s*(.-)%s*$', '%1') ~= '' then
            buf = create_buffer_fn()
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
          end
        else
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
        end
      end)
    end,
    on_exit = function(j, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.api.nvim_buf_set_lines(buf or create_buffer_fn(), 0, -1, false, j:stderr_result())
          print 'error!'
        end
      end)
    end,
  }):start()
end

vim.api.nvim_create_user_command('Gpt', function(prompt)
  utils.set_open_api_key()
  run_shell_command('sgpt ' .. '"' .. prompt.args .. '"')
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptVisual', function(prompt)
  utils.set_open_api_key()
  run_shell_command('sgpt ' .. '"' .. prompt.args .. '"', utils.get_visual_selection())
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCode', function(prompt)
  utils.set_open_api_key()
  run_shell_command(table.concat({ 'sgpt', '"' .. prompt.args .. '"', '--code' }, ' '))
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCodeVisual', function(prompt)
  utils.set_open_api_key()
  run_shell_command(table.concat({ 'sgpt', '"' .. prompt.args .. '"', '--code' }, ' '), utils.get_visual_selection())
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptGitCommitMsg', function()
  utils.set_open_api_key()
  run_shell_command 'git diff --cached | sgpt "write a short git commit message" --no-md'
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptGitDiffSummary', function()
  utils.set_open_api_key()
  run_shell_command 'git diff | sgpt "write a short git commit message" --no-md'
end, { nargs = 0 })
