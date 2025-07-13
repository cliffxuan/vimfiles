-- vibe-coding/diff.lua
-- Shows diff between AI response and main editor window

local VibeDiff = {}

VibeDiff.active_diffs = {}

function VibeDiff.extract_code_blocks(content)
  local code_blocks = {}
  local lines = vim.split(content, '\n')
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local fence_start = string.match(line, '^```(%w*)')

    if fence_start then
      local block = {
        language = fence_start ~= '' and fence_start or nil,
        content = {},
        start_line = i,
      }

      i = i + 1
      while i <= #lines do
        local current_line = lines[i]
        if string.match(current_line, '^```%s*$') then
          block.end_line = i
          break
        end
        table.insert(block.content, current_line)
        i = i + 1
      end

      if block.end_line then
        block.content_str = table.concat(block.content, '\n')
        table.insert(code_blocks, block)
      else
        table.insert(block.content, '-- [INCOMPLETE CODE BLOCK]')
        block.content_str = table.concat(block.content, '\n')
        table.insert(code_blocks, block)
      end
    end
    i = i + 1
  end

  return code_blocks
end

function VibeDiff.cleanup_diff_buffers()
  for buf_id, _ in pairs(VibeDiff.active_diffs) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      vim.api.nvim_buf_delete(buf_id, { force = true })
    end
  end
  VibeDiff.active_diffs = {}
end

function VibeDiff.show(code_block, main_win)
  -- If no code_block provided, show error
  if not code_block then
    vim.notify('[Vibe] No code block provided for diff', vim.log.levels.WARN)
    return
  end

  -- If no main_win provided or invalid, show error
  if not main_win or not vim.api.nvim_win_is_valid(main_win) then
    vim.notify('[Vibe] Main editor window is no longer valid.', vim.log.levels.ERROR)
    return
  end

  VibeDiff.cleanup_diff_buffers()

  vim.api.nvim_set_current_win(main_win)
  local main_buf = vim.api.nvim_win_get_buf(main_win)
  local main_filetype = vim.bo[main_buf].filetype
  local main_filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(main_buf), ':t')

  vim.cmd 'diffthis'
  vim.cmd 'vsplit'

  local ai_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(ai_buf)

  vim.api.nvim_buf_set_lines(ai_buf, 0, -1, false, vim.split(code_block.content_str, '\n'))

  vim.bo[ai_buf].buftype = 'nofile'
  vim.bo[ai_buf].swapfile = false
  vim.bo[ai_buf].modifiable = true
  vim.bo[ai_buf].filetype = code_block.language or main_filetype

  local ai_buf_name = 'AI-suggestion'
  if main_filename ~= '' then
    ai_buf_name = ai_buf_name .. '-' .. main_filename
  end
  vim.api.nvim_buf_set_name(ai_buf, ai_buf_name)

  vim.cmd 'diffthis'

  VibeDiff.active_diffs[ai_buf] = true

  vim.api.nvim_set_current_win(main_win)

  vim.keymap.set('n', '<leader>dq', function()
    VibeDiff.cleanup_diff_buffers()
    vim.cmd 'diffoff!'
  end, { buffer = main_buf, desc = 'Close diff and cleanup' })

  vim.keymap.set('n', '<leader>ds', function()
    vim.cmd '%diffget'
    vim.cmd 'write'
    VibeDiff.cleanup_diff_buffers()
    vim.cmd 'diffoff!'
  end, { buffer = main_buf, desc = 'Accept all AI suggestions' })

  vim.notify(
    '[Vibe] Diff opened. Use do/dp for changes, <leader>ds to accept all, <leader>dq to close',
    vim.log.levels.INFO
  )
end

return VibeDiff
