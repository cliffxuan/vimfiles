Gpt = function(...)
  local args = { ... }
  table.insert(args, '--no-md')

  local Job = require 'plenary.job'
  vim.cmd 'botright new'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  Job:new({
    command = 'sgpt',
    args = args,
    interactive = false,
    on_stdout = function(_, line)
      vim.schedule(function()
        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        if #current_lines == 1 and current_lines[1] == '' then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        else
          table.insert(current_lines, line)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, current_lines)
        end
      end)
    end,
  }):sync()
end

vim.api.nvim_create_user_command('Gpt', function(prompt)
  Gpt(prompt.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCode', function(prompt)
  Gpt(prompt.args, '--code')
end, { nargs = 1 })
