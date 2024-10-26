local Job = require 'plenary.job'
local Notify = require 'mini.notify'
local Path = require 'plenary.path'

local utils = require 'utils'

local cache_dir = os.getenv 'HOME' .. '/.local/share/nvim/gpt/'
local history_file_path = cache_dir .. os.date '%Y-%m-%d' .. '.md'

local path = Path:new(cache_dir)
if not path:exists() then
  path:mkdir { parents = true }
end

local window_config = {
  relative = 'editor',
  width = 88,
  height = 20,
  row = vim.o.lines - 24,
  col = vim.o.columns,
  border = 'rounded',
}

local load_buffer_for_path = function(file_path) -- TODO: better way to do it?
  local buf = vim.api.nvim_create_buf(false, true) -- false: not listed, true scratch
  local file = io.open(file_path, 'r')
  if file then
    local content = file:read '*all'
    if content and content ~= '' then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
    end
    file:close()
  end
  vim.api.nvim_buf_set_name(buf, file_path)
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')

  -- Auto-save function
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    callback = function()
      local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Remove trailing empty lines
      while #content > 0 and content[#content] == '' do
        table.remove(content)
      end
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

local get_window_for_file_path = function(file_path)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == vim.fn.resolve(file_path) then
      return win
    end
  end
end

local get_buffer_for_file_path = function(file_path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == vim.fn.resolve(file_path) then
      return buf
    end
  end
end

local function get_buffer(file_path)
  return get_buffer_for_file_path(file_path) or load_buffer_for_path(file_path)
end

local default_on_exit = function(job, code, buffer)
  local result = job:result()
  if code ~= 0 then
    result = job:stderr_result()
    print 'error!'
  end
  local processed_result =
    { '# ' .. os.date '!%Y-%m-%dT%H:%M:%S' .. ' >>> ' .. table.concat(vim.list_slice(job.args, 2), ' ') }
  for _, line in ipairs(result) do
    table.insert(processed_result, utils.rstrip(line))
  end
  table.insert(processed_result, '')
  vim.api.nvim_buf_set_lines(buffer, 0, 0, false, processed_result)
  local win = get_window_for_file_path(vim.api.nvim_buf_get_name(buffer))
  if not win then
    vim.api.nvim_open_win(buffer, true, window_config)
    vim.api.nvim_win_set_option(0, 'wrap', true)
  else
    vim.api.nvim_win_set_cursor(win, { 1, 1 })
    vim.api.nvim_set_current_win(win)
  end
end

local run_shell_command = function(shell_command, input, buffer, on_exit)
  if buffer == nil then
    buffer = get_buffer(history_file_path)
  end
  if on_exit == nil then
    on_exit = default_on_exit
  end

  local spinner_frames = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' }
  local frame = 1
  local get_msg = function()
    return string.format('%s %s', spinner_frames[frame], table.concat(shell_command, ' '))
  end
  local nid = Notify.add(get_msg())
  local timer = vim.loop.new_timer()
  local running = true
  timer:start(
    0,
    200,
    vim.schedule_wrap(function()
      if running then
        frame = (frame + 1) % #spinner_frames + 1
        Notify.update(nid, { msg = get_msg() })
      else
        timer:stop()
        Notify.remove(nid)
      end
    end)
  )
  Job:new({
    command = 'sh',
    writer = input,
    interactive = input ~= nil,
    args = { '-c', table.concat(shell_command, ' ') },
    on_exit = function(job, code)
      vim.schedule(function()
        running = false
        on_exit(job, code, buffer)
      end)
    end,
  }):start()
end

local gpt_prompt = function(on_submit)
  local Input = require 'nui.input'
  local event = require('nui.utils.autocmd').event

  local input = Input({
    position = '50%',
    relative = 'editor',
    size = {
      width = 100,
    },
    border = {
      style = 'rounded',
      text = {
        top = '[gpt]',
        top_align = 'center',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
    },
  }, {
    prompt = '> ',
    on_submit = function(value)
      if utils.strip(value) ~= '' then
        on_submit(value)
      end
    end,
  })

  input:mount()

  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

vim.api.nvim_create_user_command('GptWindowOpen', function()
  local win = get_window_for_file_path(history_file_path)
  if win then
    vim.api.nvim_set_current_win(win)
  else
    vim.api.nvim_open_win(get_buffer(history_file_path), true, window_config)
    vim.api.nvim_win_set_option(0, 'wrap', true)
  end
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptWindowClose', function()
  local win = get_window_for_file_path(history_file_path)
  if win then
    vim.api.nvim_win_hide(win)
  else
    print 'gpt window not found'
  end
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptWindowToggle', function()
  local win = get_window_for_file_path(history_file_path)
  if win then
    vim.api.nvim_win_hide(win)
  else
    vim.api.nvim_open_win(get_buffer(history_file_path), true, window_config)
    vim.api.nvim_win_set_option(0, 'wrap', true)
  end
end, { nargs = 0 })

vim.api.nvim_create_user_command('Gpt', function(prompt)
  utils.set_open_api_key()
  run_shell_command { 'sgpt', '"' .. prompt.args .. '"', ' --no-md' }
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptVisual', function(prompt)
  utils.set_open_api_key()
  run_shell_command({ 'sgpt ', '"', prompt.args .. '"', ' --no-md' }, utils.get_visual_selection())
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCode', function(prompt)
  utils.set_open_api_key()
  run_shell_command { 'sgpt', '"' .. prompt.args .. '"', '--code', '--no-md' }
end, { nargs = 1 })

vim.api.nvim_create_user_command('GptCodeVisual', function(prompt)
  utils.set_open_api_key()
  run_shell_command({ 'sgpt', '"' .. prompt.args .. '"', '--code', '--no-md' }, utils.get_visual_selection())
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
    local output = {}
    for _, line in ipairs(result) do
      if utils.strip(line) ~= '```' then
        table.insert(output, utils.rstrip(line))
      end
    end
    vim.api.nvim_buf_set_lines(buffer, 0, 0, false, output)
  end
  run_shell_command({ 'git diff --cached | sgpt "write a short git commit message"', '--no-md' }, nil, 0, on_exit)
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptGitDiffSummary', function()
  utils.set_open_api_key()
  run_shell_command { 'git diff | sgpt "write a short git commit message"', '--no-md' }
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptInput', function()
  gpt_prompt(function(value)
    utils.set_open_api_key()
    run_shell_command { 'sgpt', '"' .. value .. '"', ' --no-md' }
  end)
end, { nargs = 0 })

vim.api.nvim_create_user_command('GptInputVisual', function()
  gpt_prompt(function(value)
    utils.set_open_api_key()
    run_shell_command({ 'sgpt ', '"' .. value .. '"', ' --no-md' }, utils.get_visual_selection())
  end)
end, { nargs = 0 })
