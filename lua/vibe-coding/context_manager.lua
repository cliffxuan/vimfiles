-- Context Manager: Handles context file operations for chat
local Utils = require 'vibe-coding.utils'
local VibeContext = require 'vibe-coding.context'
local SessionManager = require 'vibe-coding.session_manager'

local ContextManager = {}

function ContextManager.add_context_to_chat(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end
  VibeContext.add_files_to_context(function(filepaths)
    if filepaths and #filepaths > 0 then
      local added_files = {}
      local skipped_files = {}

      for _, filepath in ipairs(filepaths) do
        local already_exists = false
        for _, existing_path in ipairs(state.context_files) do
          if existing_path == filepath then
            already_exists = true
            table.insert(skipped_files, vim.fn.fnamemodify(filepath, ':t'))
            break
          end
        end

        if not already_exists then
          table.insert(state.context_files, filepath)
          table.insert(added_files, vim.fn.fnamemodify(filepath, ':t'))
        end
      end

      require('vibe-coding.chat').update_context_buffer()

      if #added_files > 0 then
        local files_str = table.concat(added_files, '`, `')
        require('vibe-coding.chat').append_to_output('Added `' .. files_str .. '` to context.')
      end

      if #skipped_files > 0 then
        local skipped_str = table.concat(skipped_files, '`, `')
        vim.notify('[Vibe] Files already in context: `' .. skipped_str .. '`', vim.log.levels.INFO)
      end
    end
  end)
end

function ContextManager.add_buffer_context_to_chat(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end
  VibeContext.add_buffers_to_context(function(filepaths)
    if filepaths and #filepaths > 0 then
      local added_files = {}
      local skipped_files = {}

      for _, filepath in ipairs(filepaths) do
        local already_exists = false
        for _, existing_path in ipairs(state.context_files) do
          if existing_path == filepath then
            already_exists = true
            table.insert(skipped_files, vim.fn.fnamemodify(filepath, ':t'))
            break
          end
        end

        if not already_exists then
          table.insert(state.context_files, filepath)
          table.insert(added_files, vim.fn.fnamemodify(filepath, ':t'))
        end
      end

      require('vibe-coding.chat').update_context_buffer()

      if #added_files > 0 then
        local files_str = table.concat(added_files, '`, `')
        require('vibe-coding.chat').append_to_output('Added `' .. files_str .. '` to context.')
      end

      if #skipped_files > 0 then
        local skipped_str = table.concat(skipped_files, '`, `')
        vim.notify('[Vibe] Files already in context: `' .. skipped_str .. '`', vim.log.levels.INFO)
      end
    end
  end)
end

function ContextManager.remove_context_from_chat(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end

  VibeContext.remove_file_from_context(state.context_files, function(filepaths)
    if filepaths and #filepaths > 0 then
      local removed_files = {}
      local not_found_files = {}

      for _, filepath in ipairs(filepaths) do
        local found = false
        for i = #state.context_files, 1, -1 do
          if state.context_files[i] == filepath then
            table.remove(state.context_files, i)
            table.insert(removed_files, vim.fn.fnamemodify(filepath, ':t'))
            found = true
            break
          end
        end

        if not found then
          table.insert(not_found_files, vim.fn.fnamemodify(filepath, ':t'))
        end
      end

      if #removed_files > 0 then
        require('vibe-coding.chat').update_context_buffer()
        local files_str = table.concat(removed_files, '`, `')
        require('vibe-coding.chat').append_to_output('Removed `' .. files_str .. '` from context.')

        -- Save session after context change
        if SessionManager.current_session_id then
          SessionManager.save(require('vibe-coding.chat').get_messages(), state)
        end
      end

      if #not_found_files > 0 then
        local not_found_str = table.concat(not_found_files, '`, `')
        vim.notify('[Vibe] Files not found in context: `' .. not_found_str .. '`', vim.log.levels.WARN)
      end
    end
  end)
end

function ContextManager.add_current_buffer_to_context(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end

  local filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

  if filepath == '' then
    vim.notify('[Vibe] Cannot add an unnamed buffer to context.', vim.log.levels.WARN)
    return
  end

  for _, existing_path in ipairs(state.context_files) do
    if existing_path == filepath then
      vim.notify('[Vibe] File already in context.', vim.log.levels.INFO)
      return
    end
  end

  table.insert(state.context_files, filepath)
  require('vibe-coding.chat').update_context_buffer()
  require('vibe-coding.chat').append_to_output('Added `' .. vim.fn.fnamemodify(filepath, ':t') .. '` to context.')
end

function ContextManager.clear_context(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end

  if #state.context_files == 0 then
    vim.notify('[Vibe] Context is already empty.', vim.log.levels.INFO)
    return
  end

  vim.ui.input({
    prompt = 'Clear all context files? (y/N): ',
  }, function(input)
    if input and input:lower() == 'y' then
      local count = #state.context_files
      state.context_files = {}
      require('vibe-coding.chat').update_context_buffer()
      require('vibe-coding.chat').append_to_output('Cleared ' .. count .. ' files from context.')

      -- Save session after context change
      if SessionManager.current_session_id then
        SessionManager.save(require('vibe-coding.chat').get_messages(), state)
      end
    end
  end)
end

function ContextManager.remove_single_file_from_context(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end

  if #state.context_files == 0 then
    vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
    return
  end

  -- Get the current line number in the context window
  local current_win = vim.api.nvim_get_current_win()
  if current_win ~= state.context_win_id then
    vim.notify('[Vibe] Must be in context window to remove files', vim.log.levels.WARN)
    return
  end

  local cursor_line = vim.api.nvim_win_get_cursor(current_win)[1]

  -- Adjust line index to match context_files index (skip header)
  local file_index = cursor_line - 1 -- Skip the header line which starts at 1, files start from index 0
  if file_index < 1 or file_index > #state.context_files then
    vim.notify('[Vibe] Invalid line selection', vim.log.levels.WARN)
    return
  end

  local file_to_remove = state.context_files[file_index]
  if file_to_remove then
    table.remove(state.context_files, file_index)
    require('vibe-coding.chat').update_context_buffer()
    require('vibe-coding.chat').append_to_output(
      'Removed `' .. vim.fn.fnamemodify(file_to_remove, ':t') .. '` from context.'
    )

    -- Save session after context change
    if SessionManager.current_session_id then
      SessionManager.save(require('vibe-coding.chat').get_messages(), state)
    end
  else
    vim.notify('[Vibe] Could not find file to remove', vim.log.levels.WARN)
  end
end

function ContextManager.remove_selected_files_from_context(state, open_chat_window)
  if not state.layout_active then
    open_chat_window()
  end

  if #state.context_files == 0 then
    vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
    return
  end

  -- Get the current window and ensure we're in the context window
  local current_win = vim.api.nvim_get_current_win()
  if current_win ~= state.context_win_id then
    vim.notify('[Vibe] Must be in context window to remove files', vim.log.levels.WARN)
    return
  end

  -- Get visual selection range
  local start_line = vim.fn.line "'<"
  local end_line = vim.fn.line "'>"
  local context_lines = vim.api.nvim_buf_get_lines(state.context_buf_id, 0, -1, false)

  local files_to_remove = {}
  local removed_filenames = {}

  -- Process each selected line
  for line_num = start_line, end_line do
    local file_line_index = line_num - 1 -- Convert to 0-based indexing

    -- Skip header line and invalid lines
    if file_line_index > 0 and file_line_index < #context_lines then
      local selected_line = context_lines[file_line_index]
      if selected_line and selected_line ~= '' and selected_line ~= '--- Context Files ---' then
        -- Remove warning prefix if present
        local clean_line = selected_line:gsub('^⚠️  ', '')
        local clean_filename = clean_line:gsub(' %(not found%)$', '')

        -- Find the corresponding file in context_files
        for _, filepath in ipairs(state.context_files) do
          local display_path = Utils.get_relative_path(filepath)
          if display_path == clean_filename or filepath == clean_filename then
            table.insert(files_to_remove, filepath)
            table.insert(removed_filenames, vim.fn.fnamemodify(filepath, ':t'))
            break
          end
        end
      end
    end
  end

  -- Remove the files from context (reverse order to maintain indices)
  for i = #files_to_remove, 1, -1 do
    for j, filepath in ipairs(state.context_files) do
      if filepath == files_to_remove[i] then
        table.remove(state.context_files, j)
        break
      end
    end
  end

  if #removed_filenames > 0 then
    require('vibe-coding.chat').update_context_buffer()
    local files_str = table.concat(removed_filenames, '`, `')
    require('vibe-coding.chat').append_to_output('Removed `' .. files_str .. '` from context.')

    -- Save session after context change
    if SessionManager.current_session_id then
      SessionManager.save(require('vibe-coding.chat').get_messages(), state)
    end
  else
    vim.notify('[Vibe] No valid files selected for removal', vim.log.levels.WARN)
  end
end

return ContextManager
