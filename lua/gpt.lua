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

local run_shell_command = function(shell_command, input, buffer)
  if buffer == nil then
    buffer = create_buffer()
  end
  Job:new({
    command = 'sh',
    writer = input,
    interactive = input ~= nil,
    args = { '-c', shell_command },
    on_exit = function(j, code)
      vim.schedule(function()
        if code == 0 then
          vim.api.nvim_buf_set_lines(buffer, 0, 0, false, j:result())
        else
          vim.api.nvim_buf_set_lines(buffer, 0, 0, false, j:stderr_result())
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
  run_shell_command('git diff --cached | sgpt "write a short git commit message" --no-md', nil, 0)
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptGitDiffSummary', function()
  utils.set_open_api_key()
  run_shell_command 'git diff | sgpt "write a short git commit message" --no-md'
end, { nargs = 0 })
