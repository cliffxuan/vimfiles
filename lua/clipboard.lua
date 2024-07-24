local is_wsl = function()
  local wsl_check = os.getenv 'WSL_DISTRO_NAME'
  if wsl_check ~= nil then
    return true
  else
    return false
  end
end

if is_wsl() then
  vim.g.clipboard = {
    name = 'win32yank-wsl',
    copy = {
      ['+'] = 'win32yank.exe -i --crlf',
      ['*'] = 'win32yank.exe -i --crlf',
    },
    paste = {
      ['+'] = 'win32yank.exe -o --lf',
      ['*'] = 'win32yank.exe -o --lf',
    },
    cache_enabled = 0,
  }
end
