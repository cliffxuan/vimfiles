local utils = require 'utils'
local Job = require 'plenary.job'

local load_buffer_for_path = function(file_path)
  local new_buf = vim.api.nvim_create_buf(false, true) -- false: not listed, true scratch
  local file = io.open(file_path, 'r')
  if file then
    local content = file:read '*all'
    if content and content ~= '' then
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, vim.split(content, '\n'))
    end
    file:close()
  end
  return new_buf
end

local function get_buffer()
  local file_path = '/tmp/nvim-gpt.txt'
  local buf = load_buffer_for_path(file_path)
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)

  -- Auto-save function
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    callback = function()
      local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local file_w = io.open(file_path, 'w')
      if file_w then
        for _, line in ipairs(content) do
          file_w:write(line .. '\n')
        end
        file_w:close()
      else
        print('error opening file: ' .. file_path)
      end
    end,
  })

  return buf
end

local default_on_exit = function(job, code, buffer)
  local result = job:result()
  if code ~= 0 then
    result = job:stderr_result()
    print 'error!'
  end
  vim.api.nvim_buf_set_lines(buffer, 0, 0, false, result)
  vim.api.nvim_open_win(buffer, true, {
    relative = 'editor',
    width = 80,
    height = 20,
    row = vim.o.lines,
    col = vim.o.columns,
    style = 'minimal',
  })
end

local run_shell_command = function(shell_command, input, buffer, on_exit)
  if buffer == nil then
    buffer = get_buffer()
  end
  if on_exit == nil then
    on_exit = default_on_exit
  end
  Job:new({
    command = 'sh',
    writer = input,
    interactive = input ~= nil,
    args = { '-c', shell_command },
    on_exit = function(job, code)
      vim.schedule(function()
        on_exit(job, code, buffer)
      end)
    end,
  }):start()
end

vim.api.nvim_create_user_command('GptWindowShow', function()
  vim.api.nvim_open_win(get_buffer(), true, {
    relative = 'editor',
    width = 80,
    height = 20,
    row = vim.o.lines,
    col = vim.o.columns,
    style = 'minimal',
  })
end, { nargs = 0 })

vim.api.nvim_create_user_command('Gpt', function(prompt)
  utils.set_open_api_key()
  local on_exit = function(job, code, buffer)
    default_on_exit(job, code, buffer)
  end
  run_shell_command('sgpt ' .. '"' .. prompt.args .. '"', nil, get_buffer(), on_exit)
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
  local filetype = vim.bo.filetype
  if filetype ~= 'gitcommit' then
    print 'use this at fugitive gitcommit window'
    return
  end
  utils.set_open_api_key()
  local on_exit = function(job, code, buffer)
    local result = job:result()
    if code ~= 0 then
      result = job:stderr_result()
      print 'error!'
    end
    vim.api.nvim_buf_set_lines(buffer, 0, 0, false, result)
  end
  run_shell_command('git diff --cached | sgpt "write a short git commit message" --no-md', nil, 0, on_exit)
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptGitDiffSummary', function()
  utils.set_open_api_key()
  run_shell_command 'git diff | sgpt "write a short git commit message" --no-md'
end, { nargs = 0 })
