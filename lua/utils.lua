local M = {}

M.get_highlighted_text = function()
  local hl_text = vim.fn.getreg '/'
  hl_text = string.gsub(hl_text, '\\[<>]', '\\b') -- word boundary \<\> -> \b, e,g, \<abc\> -> \babc\b
  hl_text = string.gsub(hl_text, '\\_s\\+', '\\s+') -- whitespace \_s\+ -> \s+
  hl_text = string.gsub(hl_text, '\\V', '') -- prefix indicating visualed selected
  hl_text = string.gsub(hl_text, '%(', '\\(') -- escape (
  hl_text = string.gsub(hl_text, '%)', '\\)') -- escape )
  return hl_text
end

M.get_visual_selection = function()
  -- this will exit visual mode
  -- use 'gv' to reselect the text
  local _, csrow, cscol, cerow, cecol
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '' then
    -- if we are in visual mode use the live position
    _, csrow, cscol, _ = unpack(vim.fn.getpos '.')
    _, cerow, cecol, _ = unpack(vim.fn.getpos 'v')
    if mode == 'V' then
      -- visual line doesn't provide columns
      cscol, cecol = 0, 999
    end
  else
    -- otherwise, use the last known visual position
    _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")
  end
  -- swap vars if needed
  if cerow < csrow then
    csrow, cerow = cerow, csrow
  end
  if cecol < cscol then
    cscol, cecol = cecol, cscol
  end
  local lines = vim.fn.getline(csrow, cerow)
  -- local n = cerow-csrow+1
  local n = #lines
  if n <= 0 then
    return ''
  end
  lines[n] = string.sub(lines[n], 1, cecol)
  lines[1] = string.sub(lines[1], cscol)
  return table.concat(lines, '\n')
end

-- This function checks if the current environment is Windows Subsystem for Linux (WSL)
M.is_wsl = function()
  local wsl_check = os.getenv 'WSL_DISTRO_NAME'
  if wsl_check ~= nil then
    return true
  else
    return false
  end
end

M.set_open_api_key = function()
  local openai_api_key_path = vim.fn.expand '~/.config/openai_api_key'
  if vim.fn.filereadable(openai_api_key_path) == 1 then
    local openai_api_key = vim.fn.systemlist('cat ' .. openai_api_key_path)[1]
    vim.env.OPENAI_API_KEY = openai_api_key
  end
end

M.rstrip = function(s)
  return s:match '^(.*%S)' or ''
end

M.strip = function(s)
  return s:match '^%s*(.-)%s*$'
end

M.split = function(s)
  local result = {}
  for word in s:gmatch '%S+' do
    table.insert(result, word)
  end
  return result
end

M.find_project_root = function()
  -- Get initial directory: either file's directory or current working directory
  local current_file = vim.fn.expand '%:p'
  local current_dir = current_file ~= '' and vim.fn.fnamemodify(current_file, ':h') or vim.fn.getcwd()

  -- Project root markers
  local markers = {
    '.rootdir',
    '.git',
    '.hg',
    '.svn',
    '.bzr',
    'site-packages',
  }

  -- Traverse up the directory tree
  local dir = current_dir
  while dir ~= '/' and dir ~= '.' do -- Better path termination check
    -- Check for any marker
    for _, marker in ipairs(markers) do
      local marker_path = dir .. '/' .. marker
      if vim.fn.isdirectory(marker_path) == 1 then
        return dir
      end
    end

    -- Move to parent directory
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then -- Prevent infinite loop
      break
    end
    dir = parent
  end

  -- Fallback to starting directory if no root found
  return current_dir
end

M.guess_project_root = function()
  local ok, result = pcall(M.find_project_root)
  if not ok then
    vim.notify('Error finding project root: ' .. tostring(result), vim.log.levels.ERROR)
    return vim.fn.getcwd()
  end
  return result
end

return M
