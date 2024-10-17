Gpt = function(...)
  local args = { ... }
  table.insert(args, '--no-md')

  local Job = require 'plenary.job'
  local openai_api_key_path = vim.fn.expand '~/.config/openai_api_key'
  if vim.fn.filereadable(openai_api_key_path) == 1 then
    local openai_api_key = vim.fn.systemlist('cat ' .. openai_api_key_path)[1]
    vim.env.OPENAI_API_KEY = openai_api_key
  end
  local buf = nil
  Job:new({
    command = 'sgpt',
    args = args,
    interactive = false,
    on_stdout = function(_, line)
      vim.schedule(function()
        if not buf then
          vim.cmd 'botright new'
          buf = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
          vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
          vim.api.nvim_buf_set_option(buf, 'swapfile', false)
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

vim.api.nvim_create_user_command('Gpt', function(prompt)
  Gpt(prompt.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCode', function(prompt)
  Gpt(prompt.args, '--code')
end, { nargs = 1 })