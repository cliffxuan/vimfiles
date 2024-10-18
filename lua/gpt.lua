local utils = require 'utils'
local Job = require 'plenary.job'
local function create_buffer()
  vim.cmd 'botright new'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  return buf
end

Gpt = function(input, ...)
  local args = { ... }
  table.insert(args, '--no-md')

  local openai_api_key_path = vim.fn.expand '~/.config/openai_api_key'
  if vim.fn.filereadable(openai_api_key_path) == 1 then
    local openai_api_key = vim.fn.systemlist('cat ' .. openai_api_key_path)[1]
    vim.env.OPENAI_API_KEY = openai_api_key
  end
  local buf = nil
  Job:new({
    command = 'sgpt',
    args = args,
    writer = input,
    interactive = input ~= nil,
    on_stdout = function(_, line)
      vim.schedule(function()
        if not buf then
          buf = create_buffer()
        end
        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if #current_lines == 1 and current_lines[1] == '' then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        else
          table.insert(current_lines, line)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, current_lines)
        end
      end)
    end,
    on_exit = function(j, return_val)
      if return_val ~= 0 then
        print('Error executing command', table.concat(j:stderr_result(), '\n'))
      end
    end,
  }):start()
end

GptGitCommitMsg = function()
  local git_diff = Job:new {
    command = 'git',
    args = { 'diff', '--cached' },
  }
  local gen_commit_msg = Job:new {
    command = 'sgpt',
    args = { 'one line git commit message' },
    writer = git_diff,
    on_exit = function(j, code)
      vim.schedule(function()
        if code == 0 then
          local current_line = vim.fn.line '.'
          vim.api.nvim_buf_set_lines(0, 0, 0, false, j:result())
          vim.api.nvim_win_set_cursor(0, { current_line, 0 })
        else
          print('Error executing command', table.concat(j:stderr_result(), '\n'))
        end
      end)
    end,
  }
  git_diff:after(function()
    gen_commit_msg:start()
  end)

  git_diff:start()
end

vim.api.nvim_create_user_command('Gpt', function(prompt)
  Gpt(nil, prompt.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptVisual', function(prompt)
  Gpt(utils.get_visual_selection(), prompt.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCode', function(prompt)
  Gpt(nil, prompt.args, '--code')
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCodeVisual', function(prompt)
  Gpt(utils.get_visual_selection(), prompt.args, '--code')
end, { nargs = 1 })
