-- Set a key mapping that calls the Lua function
-- vim.keymap.set('n', '<leader>as', function()
--   local selected_text = vim.fn.getreg '/'
--   selected_text = string.gsub(selected_text, '\\[<>]', '\\b') -- word boundary \<\> -> \b, e,g, \<abc\> -> \babc\b
--   selected_text = string.gsub(selected_text, '\\_s\\+', '\\s+') -- whitespace \_s\+ -> \s+
--   vim.cmd('Rg ' .. selected_text)
-- end, { desc = "Search hilighted text"})
-- search_hilighted_text()
local function get_cursor_word()
  local current_word = vim.fn.expand '<cword>'
  print(current_word)
end

-- get_cursor_word()
-- print(vim.fn.expand('%:p'))
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
print(lazypath)

EchoHi = function()
  print 'hi'
end

GptPopup = function(...)
  local args = { ... }
  table.insert(args, '--no-md')
  local Popup = require 'nui.popup'
  local Layout = require 'nui.layout'

  local popup = Popup {
    enter = true,
    border = 'single',
  }

  local layout = Layout(
    {
      position = '50%',
      size = {
        width = '80%',
        height = '60%',
      },
    },
    Layout.Box({
      Layout.Box(popup, { size = '100%' }),
    }, { dir = 'row' })
  )
  layout:mount()

  local Job = require 'plenary.job'
  Job:new({
    command = 'sgpt',
    args = args,
    interactive = false,
    on_stdout = function(_, line)
      vim.schedule(function()
        local current_lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
        if #current_lines == 1 and current_lines[1] == '' then
          vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, { line })
        else
          table.insert(current_lines, line)
          vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, current_lines)
        end
      end)
    end,
  }):sync()
end
