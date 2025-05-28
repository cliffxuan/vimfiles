-- format_long_strings.lua
-- A Neovim plugin to format long Python string literals according to PEP 8

local M = {}

-- Maximum line length (PEP 8 recommends 79 for code, 88 for Black)
local MAX_LINE_LENGTH = 88

-- Format a long string into multiple lines
function M.format_long_string()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_nr = cursor[1] - 1 -- 0-indexed
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1]
  -- Check if we're on a line with a string
  local start_idx, end_idx, quote_type, prefix
  -- Look for raw strings (r"..." or r'...')
  start_idx, end_idx, prefix, quote_type = line:find '([rfbu]*)(["\'])'
  if not start_idx then
    -- Look for normal strings
    start_idx, end_idx, quote_type = line:find '(["\'])'
    prefix = ''
  end

  if not start_idx then
    vim.notify('No string found on current line', vim.log.levels.WARN)
    return
  end

  -- Find the matching closing quote
  local in_escape = false
  local string_end = nil
  for i = end_idx + 1, #line do
    local char = line:sub(i, i)
    if in_escape then
      in_escape = false
    elseif char == '\\' then
      in_escape = true
    elseif char == quote_type then
      string_end = i
      break
    end
  end

  if not string_end then
    vim.notify('Could not find closing quote', vim.log.levels.WARN)
    return
  end

  -- Extract the string content
  local string_content = line:sub(end_idx + 1, string_end - 1)

  -- Check if we need to format (if line is too long)
  if #line <= MAX_LINE_LENGTH then
    vim.notify('Line is already within length limit', vim.log.levels.INFO)
    return
  end

  -- Calculate the indentation level
  local indent = line:match '^%s*'
  local indent_next_line = indent .. '    ' -- 4 spaces for continuation
  local formatted_lines = {}
  table.insert(formatted_lines, line:sub(1, start_idx - 1) .. '(' .. prefix)
  local chunk_size = MAX_LINE_LENGTH - #indent_next_line - 2 -- -2 for the quotes
  for i = 1, #string_content, chunk_size do
    local chunk = string_content:sub(i, i + chunk_size - 1)
    table.insert(formatted_lines, indent_next_line .. quote_type .. chunk .. quote_type)
  end

  -- Add closing parenthesis on a new line
  table.insert(formatted_lines, indent .. ')')

  -- Add the rest of the original line after the string
  if string_end < #line then
    formatted_lines[#formatted_lines] = formatted_lines[#formatted_lines] .. line:sub(string_end + 1)
  end

  -- Replace the current line with the formatted lines
  vim.api.nvim_buf_set_lines(bufnr, line_nr, line_nr + 1, false, formatted_lines)
  vim.notify('String formatted successfully', vim.log.levels.INFO)
end

-- Register the command
vim.api.nvim_create_user_command('FormatLongString', function()
  M.format_long_string()
end, {})

return M
