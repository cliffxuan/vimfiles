-- SessionManager: Handles session persistence and management
local Utils = require 'vibe-coding.utils'

local SessionManager = {}

SessionManager.current_session_id = nil
SessionManager.sessions_dir = vim.fn.stdpath 'data' .. '/vibe-sessions'

-- Initialize sessions directory
function SessionManager.init()
  -- Create sessions directory if it doesn't exist
  if vim.fn.isdirectory(SessionManager.sessions_dir) == 0 then
    vim.fn.mkdir(SessionManager.sessions_dir, 'p')
  end
end

-- Start a new session or load existing one
function SessionManager.start(session_name, state, update_context_buffer, append_to_output)
  -- Initialize sessions directory
  SessionManager.init()

  if not session_name or session_name == '' then
    -- Generate a timestamp-based session name if none provided
    session_name = os.date '%Y%m%d_%H%M%S'
  end

  -- Sanitize session name to be filesystem-friendly
  session_name = session_name:gsub('[^%w_%-]', '_')

  local session_file = SessionManager.sessions_dir .. '/' .. session_name .. '.json'
  SessionManager.current_session_id = session_name

  -- Reset the output buffer
  if state.output_buf_id and vim.api.nvim_buf_is_valid(state.output_buf_id) then
    vim.bo[state.output_buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(state.output_buf_id, 0, -1, false, {})

    -- Add welcome header with API URL, Model and Prompt name
    local PromptManager = require 'vibe-coding.prompt_manager'
    local CONFIG = require('vibe-coding.init').CONFIG
    local prompt_display_name = PromptManager.selected_prompt_name or 'unknown-prompt'
    local header_lines = {
      'Welcome to Vibe Coding!',
      'API URL: ' .. CONFIG.api_url,
      'Model: ' .. CONFIG.model,
      'Prompt: ' .. prompt_display_name,
      '',
    }
    vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, header_lines)
  end

  -- Check if session already exists
  if vim.fn.filereadable(session_file) == 1 then
    -- Load existing session
    local content, read_err = Utils.read_file(session_file)
    if not content then
      vim.notify('[Vibe] Failed to load session: ' .. read_err, vim.log.levels.ERROR)
      return session_name
    end

    local session_data, json_err = Utils.json_decode(table.concat(content, '\n'))
    if not session_data then
      vim.notify('[Vibe] Failed to parse session: ' .. json_err, vim.log.levels.ERROR)
      return session_name
    end

    -- Restore messages
    local messages_for_display = session_data.messages or {}

    -- Restore context files
    state.context_files = session_data.context_files or {}
    update_context_buffer()

    -- Update the output buffer with the conversation history
    if state.output_buf_id and vim.api.nvim_buf_is_valid(state.output_buf_id) then
      -- Add session info
      vim.api.nvim_buf_set_lines(
        state.output_buf_id,
        -1,
        -1,
        false,
        vim.split('📂 Loaded session: ' .. session_name, '\n')
      )
      vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, { '' })

      -- Rebuild conversation history
      for _, msg in ipairs(messages_for_display) do
        if msg.role == 'user' then
          vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, vim.split('👤 You:\n' .. msg.content, '\n'))
          vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, { '' })
        elseif msg.role == 'assistant' then
          vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, vim.split('🤖 AI:\n' .. msg.content, '\n'))
          vim.api.nvim_buf_set_lines(state.output_buf_id, -1, -1, false, { '' })
        end
      end

      vim.bo[state.output_buf_id].modifiable = false

      -- Scroll to bottom
      local win_id = state.output_win_id
      if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(state.output_buf_id), 0 })
      end
    end

    vim.notify('[Vibe] Loaded session: ' .. session_name, vim.log.levels.INFO)
    return session_name, messages_for_display
  else
    -- Create new session
    -- Reset messages_for_display for new sessions
    local messages_for_display = {}

    -- Clear context files for new session
    state.context_files = {}

    -- Add current buffer to context if it has a name
    local current_buf = vim.api.nvim_buf_get_name(
      state.main_editor_win_id and vim.api.nvim_win_get_buf(state.main_editor_win_id) or vim.api.nvim_get_current_buf()
    )
    if current_buf and current_buf ~= '' then
      table.insert(state.context_files, current_buf)
    end

    -- Update context buffer display
    update_context_buffer()

    -- Add session info to output
    if state.output_buf_id and vim.api.nvim_buf_is_valid(state.output_buf_id) then
      vim.api.nvim_buf_set_lines(
        state.output_buf_id,
        -1,
        -1,
        false,
        vim.split('📂 Started session: ' .. session_name, '\n')
      )
      vim.bo[state.output_buf_id].modifiable = false
    end

    SessionManager.save(messages_for_display, state)
    vim.notify('[Vibe] Started new session: ' .. session_name, vim.log.levels.INFO)
    return session_name, messages_for_display
  end
end

-- Save current session
function SessionManager.save(messages_for_display, state)
  if not SessionManager.current_session_id then
    return false
  end

  local session_file = SessionManager.sessions_dir .. '/' .. SessionManager.current_session_id .. '.json'
  local session_data = {
    messages = messages_for_display,
    context_files = state.context_files,
    timestamp = os.time(),
  }

  local json_str, json_err = Utils.json_encode(session_data)
  if not json_str then
    vim.notify('[Vibe] Failed to save session: ' .. json_err, vim.log.levels.ERROR)
    return false
  end

  local success, write_err = Utils.write_file(session_file, { json_str })
  if not success then
    vim.notify('[Vibe] Failed to save session: ' .. write_err, vim.log.levels.ERROR)
    return false
  end

  return true
end

-- End current session (just saves it)
function SessionManager.end_session(messages_for_display, state)
  if not SessionManager.current_session_id then
    vim.notify('[Vibe] No active session to end.', vim.log.levels.WARN)
    return false
  end

  local session_name = SessionManager.current_session_id
  SessionManager.save(messages_for_display, state)
  vim.notify('[Vibe] Saved and ended session: ' .. session_name, vim.log.levels.INFO)

  -- Don't clear the current_session_id so we keep saving to the same session
  return true
end

-- List all available sessions
function SessionManager.list(callback)
  SessionManager.init()

  local sessions = {}
  local files = vim.fn.glob(SessionManager.sessions_dir .. '/*.json', false, true)

  -- Create a table with session names and their modification times
  local sessions_with_times = {}
  for _, file in ipairs(files) do
    local session_name = vim.fn.fnamemodify(file, ':t:r')
    local mod_time = vim.fn.getftime(file)
    table.insert(sessions_with_times, { name = session_name, time = mod_time })
  end

  -- Sort by modification time (most recent first)
  table.sort(sessions_with_times, function(a, b)
    return a.time > b.time
  end)

  -- Extract just the session names in the sorted order
  for _, session in ipairs(sessions_with_times) do
    table.insert(sessions, session.name)
  end

  if #sessions == 0 then
    vim.notify('[Vibe] No saved sessions found.', vim.log.levels.INFO)
    return {}
  end

  if callback then
    callback(sessions)
  end

  return sessions
end

-- Helper function to load sessions with metadata
function SessionManager.load_sessions_with_data()
  SessionManager.init()

  local files = vim.fn.glob(SessionManager.sessions_dir .. '/*.json', false, 1)
  if #files == 0 then
    return nil
  end

  local sessions_with_data = {}
  for _, file in ipairs(files) do
    local session_name = vim.fn.fnamemodify(file, ':t:r')
    local mod_time = vim.fn.getftime(file)
    local mod_date = os.date('%Y-%m-%d %H:%M:%S', mod_time)

    local content, _ = Utils.read_file(file)
    local session_data = nil
    if content then
      session_data, _ = Utils.json_decode(table.concat(content, '\n'))
    end

    table.insert(sessions_with_data, {
      name = session_name,
      file = file,
      time = mod_time,
      date = mod_date,
      data = session_data,
      display = session_name .. ' (' .. mod_date .. ')',
    })
  end

  table.sort(sessions_with_data, function(a, b)
    return a.time > b.time
  end)

  return sessions_with_data
end

-- Helper function to create session preview
function SessionManager.create_session_preview(session)
  local lines = {}

  table.insert(lines, '📂 Session: ' .. session.name)
  table.insert(lines, '📅 Modified: ' .. session.date)
  table.insert(lines, '')

  if session.data then
    if session.data.context_files and #session.data.context_files > 0 then
      table.insert(lines, '📁 Context Files (' .. #session.data.context_files .. '):')
      for i, file in ipairs(session.data.context_files) do
        local rel_path = Utils.get_relative_path(file)
        table.insert(lines, '  ' .. i .. '. ' .. rel_path)
      end
      table.insert(lines, '')
    else
      table.insert(lines, '📁 Context Files: None')
      table.insert(lines, '')
    end

    if session.data.messages and #session.data.messages > 0 then
      table.insert(lines, '💬 Messages (' .. #session.data.messages .. '):')
      table.insert(lines, '')

      local start_idx = math.max(1, #session.data.messages - 4)
      for i = start_idx, #session.data.messages do
        local msg = session.data.messages[i]
        if msg.role == 'user' then
          table.insert(lines, '👤 You:')
          local content_lines = vim.split(msg.content, '\n')
          for j = 1, math.min(3, #content_lines) do
            table.insert(lines, '  ' .. content_lines[j])
          end
          if #content_lines > 3 then
            table.insert(lines, '  ...')
          end
        elseif msg.role == 'assistant' then
          table.insert(lines, '🤖 AI:')
          local content_lines = vim.split(msg.content, '\n')
          for j = 1, math.min(3, #content_lines) do
            table.insert(lines, '  ' .. content_lines[j])
          end
          if #content_lines > 3 then
            table.insert(lines, '  ...')
          end
        end
        table.insert(lines, '')
      end
    else
      table.insert(lines, '💬 Messages: None')
    end
  else
    table.insert(lines, '⚠️  Could not read session data')
  end

  return lines
end

function SessionManager.get_most_recent()
  SessionManager.init()

  local files = vim.fn.glob(SessionManager.sessions_dir .. '/*.json', false, true)
  if #files == 0 then
    return nil
  end

  -- Sort files by modification time (most recent first)
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  -- Return the most recent session name
  return vim.fn.fnamemodify(files[1], ':t:r')
end

-- Rename session functionality
function SessionManager.rename_interactive(append_to_output)
  -- If no active session, notify and return
  if not SessionManager.current_session_id then
    vim.notify('[Vibe] No active session to rename.', vim.log.levels.WARN)
    return
  end

  local current_name = SessionManager.current_session_id

  vim.ui.input({
    prompt = "New name for session '" .. current_name .. "': ",
    default = current_name,
  }, function(new_name)
    if not new_name or new_name == '' or new_name == current_name then
      return
    end

    -- Sanitize new session name to be filesystem-friendly
    new_name = new_name:gsub('[^%w_%-]', '_')

    -- Check if destination already exists
    local new_file = SessionManager.sessions_dir .. '/' .. new_name .. '.json'
    if vim.fn.filereadable(new_file) == 1 then
      vim.ui.input({
        prompt = "Session '" .. new_name .. "' already exists. Overwrite? (y/N): ",
      }, function(input)
        if not input or input:lower() ~= 'y' then
          vim.notify('[Vibe] Session rename cancelled.', vim.log.levels.INFO)
          return
        end
        SessionManager.perform_rename(current_name, new_name, append_to_output)
      end)
    else
      SessionManager.perform_rename(current_name, new_name, append_to_output)
    end
  end)
end

-- Helper function to actually perform the rename operation
function SessionManager.perform_rename(old_name, new_name, append_to_output)
  local old_file = SessionManager.sessions_dir .. '/' .. old_name .. '.json'
  local new_file = SessionManager.sessions_dir .. '/' .. new_name .. '.json'

  -- Read the old session file
  if vim.fn.filereadable(old_file) ~= 1 then
    vim.notify('[Vibe] Error: Session file not found.', vim.log.levels.ERROR)
    return
  end

  local content = vim.fn.readfile(old_file)

  -- Write to the new session file
  local success = vim.fn.writefile(content, new_file) == 0

  if success then
    -- Delete the old file only if write was successful
    vim.fn.delete(old_file)

    -- Update current session ID
    SessionManager.current_session_id = new_name

    -- Update the output buffer with the new session name
    append_to_output('📂 Renamed session: ' .. old_name .. ' → ' .. new_name)

    vim.notify('[Vibe] Session renamed: ' .. old_name .. ' → ' .. new_name, vim.log.levels.INFO)
  else
    vim.notify('[Vibe] Failed to rename session.', vim.log.levels.ERROR)
  end
end

return SessionManager
