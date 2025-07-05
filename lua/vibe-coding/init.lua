-- vibe-coding.lua
-- A single-file OpenAI coding assistant for Neovim

-- =============================================================================
-- Configuration Constants
-- =============================================================================
local CONFIG = {
  -- API Configuration
  api_key = os.getenv 'OPENAI_API_KEY',
  api_url = os.getenv 'OPENAI_API_BASE_URL' or 'https://api.openai.com/v1',
  model = os.getenv 'OPENAI_CHAT_MODEL_ID' or 'gpt-4.1-mini',

  -- UI Configuration
  sidebar_width = 80,
  input_height_ratio = 0.1,
  context_height_ratio = 0.1,
  min_input_height = 3,
  min_context_height = 2,

  -- File Cache Settings
  cache_enabled = true,
  max_cache_entries = 100,

  -- Debug Settings
  debug_mode = false,
}

-- =============================================================================
-- Utility Functions
-- =============================================================================
local Utils = {}

-- Safe JSON operations with error handling
function Utils.json_encode(data)
  local ok, result = pcall(vim.fn.json_encode, data)
  if not ok then
    return nil, 'Failed to encode JSON: ' .. tostring(result)
  end
  return result, nil
end

function Utils.json_decode(str)
  local ok, result = pcall(vim.fn.json_decode, str)
  if not ok then
    return nil, 'Failed to decode JSON: ' .. tostring(result)
  end
  return result, nil
end

-- Safe file operations with error handling
function Utils.read_file(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil, 'File not readable: ' .. filepath
  end

  local ok, content = pcall(vim.fn.readfile, filepath)
  if not ok then
    return nil, 'Failed to read file: ' .. filepath
  end

  return content, nil
end

function Utils.write_file(filepath, content)
  local ok, _ = pcall(vim.fn.writefile, content, filepath)
  if not ok then
    return false, 'Failed to write file: ' .. filepath
  end
  return true, nil
end

-- Get relative path for display purposes (extracted from repeated code)
function Utils.get_relative_path(file_path)
  -- Check if file is in a git repo and get relative path if possible
  local file_dir = vim.fn.fnamemodify(file_path, ':h')
  local git_root_cmd = 'cd ' .. vim.fn.shellescape(file_dir) .. ' && git rev-parse --show-toplevel 2>/dev/null'
  local git_root = vim.fn.trim(vim.fn.system(git_root_cmd))

  local display_path = file_path
  if git_root ~= '' and vim.v.shell_error == 0 then
    local rel_path_cmd = 'realpath --relative-to='
      .. vim.fn.shellescape(git_root)
      .. ' '
      .. vim.fn.shellescape(file_path)
    local rel_path = vim.fn.trim(vim.fn.system(rel_path_cmd))

    if rel_path ~= '' and vim.v.shell_error == 0 then
      display_path = rel_path
    end
  end

  return display_path
end

-- File content caching system
local FileCache = {}
FileCache.cache = {}
FileCache.access_order = {}

function FileCache.get_content(filepath)
  if not CONFIG.cache_enabled then
    local content, err = Utils.read_file(filepath)
    if not content then
      return nil, err
    end
    return table.concat(content, '\n'), nil
  end

  local mtime = vim.fn.getftime(filepath)
  if mtime == -1 then
    return nil, 'File does not exist: ' .. filepath
  end

  -- Check cache
  local cached = FileCache.cache[filepath]
  if cached and cached.mtime >= mtime then
    -- Update access order
    FileCache._update_access(filepath)
    return cached.content, nil
  end

  -- Read file and cache
  local content, err = Utils.read_file(filepath)
  if not content then
    return nil, err
  end

  local content_str = table.concat(content, '\n')
  FileCache._add_to_cache(filepath, content_str, mtime)

  return content_str, nil
end

function FileCache._add_to_cache(filepath, content, mtime)
  -- Remove if already exists
  if FileCache.cache[filepath] then
    FileCache._remove_from_access_order(filepath)
  end

  -- Add to cache
  FileCache.cache[filepath] = {
    content = content,
    mtime = mtime,
  }

  -- Add to access order
  table.insert(FileCache.access_order, filepath)

  -- Maintain cache size
  if #FileCache.access_order > CONFIG.max_cache_entries then
    local oldest = table.remove(FileCache.access_order, 1)
    FileCache.cache[oldest] = nil
  end
end

function FileCache._update_access(filepath)
  FileCache._remove_from_access_order(filepath)
  table.insert(FileCache.access_order, filepath)
end

function FileCache._remove_from_access_order(filepath)
  for i, path in ipairs(FileCache.access_order) do
    if path == filepath then
      table.remove(FileCache.access_order, i)
      break
    end
  end
end

-- =============================================================================
-- Vibe API: Handles communication with the OpenAI API
-- =============================================================================
local VibeAPI = {}

do
  local plenary_job = require 'plenary.job'

  -- Function to write debug curl script
  function VibeAPI.write_debug_script(messages)
    local data = {
      model = CONFIG.model,
      messages = messages,
      stream = true,
    }

    local json_data, json_err = Utils.json_encode(data)
    if not json_data then
      vim.notify('[Vibe] Failed to encode JSON for debug script: ' .. json_err, vim.log.levels.ERROR)
      return
    end

    -- Create debug directory if it doesn't exist
    local debug_dir = vim.fn.stdpath 'data' .. '/vibe-debug'
    if vim.fn.isdirectory(debug_dir) == 0 then
      vim.fn.mkdir(debug_dir, 'p')
    end

    local timestamp = os.date '%Y%m%d_%H%M%S'
    local script_path = debug_dir .. '/vibe_api_call_' .. timestamp .. '.sh'
    local json_path = debug_dir .. '/vibe_request_' .. timestamp .. '.json'

    -- Write JSON data to separate file for readability
    local json_success, json_write_err = Utils.write_file(json_path, { json_data })
    if not json_success then
      vim.notify('[Vibe] Failed to write debug JSON: ' .. json_write_err, vim.log.levels.ERROR)
      return
    end

    -- Create the curl command script
    local endpoint = CONFIG.api_url .. '/chat/completions'
    local script_content = {
      '#!/bin/bash',
      '# Vibe AI API Debug Script - Generated at ' .. os.date '%Y-%m-%d %H:%M:%S',
      '# Model: ' .. CONFIG.model,
      '# API URL: ' .. endpoint,
      '',
      'echo "Making API call to ' .. endpoint .. '"',
      'echo "Using model: ' .. CONFIG.model .. '"',
      'echo "Request payload saved to: ' .. json_path .. '"',
      'echo ""',
      '',
      'curl -s -N -X POST \\',
      '  "' .. endpoint .. '" \\',
      '  -H "Content-Type: application/json" \\',
      '  -H "Authorization: Bearer $OPENAI_API_KEY" \\',
      '  -d @"' .. json_path .. '"',
      '',
      'echo ""',
      'echo "Debug script completed"',
    }

    local script_success, script_write_err = Utils.write_file(script_path, script_content)
    if not script_success then
      vim.notify('[Vibe] Failed to write debug script: ' .. script_write_err, vim.log.levels.ERROR)
      return
    end

    -- Make script executable
    vim.fn.system('chmod +x ' .. vim.fn.shellescape(script_path))

    vim.notify('[Vibe] Debug script written to: ' .. script_path, vim.log.levels.INFO)
    return script_path, json_path
  end

  -- Function to get streaming completion
  function VibeAPI.get_completion(messages, callback, stream_callback)
    if not CONFIG.api_key or CONFIG.api_key == '' then
      vim.notify('[Vibe] OPENAI_API_KEY environment variable not set.', vim.log.levels.ERROR)
      callback(nil, 'API Key not set.')
      return
    end

    local data = {
      model = CONFIG.model,
      messages = messages,
      stream = true,
    }

    -- Safe JSON encoding
    local json_data, json_err = Utils.json_encode(data)
    if not json_data then
      callback(nil, json_err)
      return
    end

    -- Write debug script if debug mode is enabled
    if CONFIG.debug_mode then
      VibeAPI.write_debug_script(messages)
    end

    -- Create a temporary file for the JSON payload
    local temp_json_path = vim.fn.tempname()
    local temp_file_success, temp_file_err = Utils.write_file(temp_json_path, { json_data })
    if not temp_file_success then
      vim.notify('[Vibe] Failed to write temporary request file: ' .. temp_file_err, vim.log.levels.ERROR)
      callback(nil, 'Failed to create temp file for request.')
      return
    end

    local accumulated_content = ''
    local buffer = ''

    plenary_job
      ---@diagnostic disable-next-line
      :new({
        command = 'curl',
        args = {
          '-s',
          '-N',
          '-X',
          'POST',
          CONFIG.api_url .. '/chat/completions',
          '-H',
          'Content-Type: application/json',
          '-H',
          'Authorization: Bearer ' .. CONFIG.api_key,
          '-d',
          '@' .. temp_json_path, -- Use the temporary file for the payload
        },
        on_stdout = vim.schedule_wrap(function(_, data_chunk)
          if not data_chunk or data_chunk == '' then
            return
          end

          buffer = buffer .. data_chunk .. '\n'
          local lines = vim.split(buffer, '\n', { plain = true })
          buffer = lines[#lines]

          for i = 1, #lines - 1 do
            local line = lines[i]
            if line:match '^data: ' then
              local json_str = line:sub(7) -- Remove 'data: ' prefix
              if json_str == '[DONE]' then
                return
              end

              local chunk_data, _ = Utils.json_decode(json_str)
              if chunk_data and chunk_data.choices and #chunk_data.choices > 0 then
                local delta = chunk_data.choices[1].delta
                if delta and delta.content then
                  accumulated_content = accumulated_content .. delta.content
                  if stream_callback then
                    stream_callback(delta.content)
                  end
                end
              end
            end
          end
        end),
        on_exit = vim.schedule_wrap(function(job, return_val)
          -- Clean up the temporary file
          vim.fn.delete(temp_json_path)

          if return_val == 0 then
            vim.notify '[Vibe] Done calling API'
            callback(accumulated_content)
          else
            local stderr = job:stderr_result()
            local error_msg = stderr and table.concat(stderr, '\n') or 'HTTP request failed.'
            vim.notify('[Vibe] Error calling API: ' .. error_msg, vim.log.levels.ERROR)
            callback(nil, error_msg)
          end
        end),
      })
      :start()
  end
end

-- =============================================================================
-- Vibe Context: Manages adding file context using Telescope
-- =============================================================================
local VibeContext = {}
do
  function VibeContext.add_files_to_context(callback)
    local telescope = require 'telescope.builtin'
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    telescope.find_files {
      prompt_title = 'Select files for context (Tab to multi-select)',
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selections = {}
          local picker = action_state.get_current_picker(prompt_bufnr)

          -- Get multi-selected files
          local multi_selection = picker:get_multi_selection()
          if #multi_selection > 0 then
            for _, entry in ipairs(multi_selection) do
              table.insert(selections, entry.path or entry.value)
            end
          else
            -- Get single selection if no multi-selection
            local entry = action_state.get_selected_entry()
            if entry then
              table.insert(selections, entry.path or entry.value)
            end
          end

          actions.close(prompt_bufnr)

          if #selections > 0 then
            callback(selections)
          end
        end)

        return true
      end,
    }
  end

  -- Legacy single file function for backward compatibility
  function VibeContext.add_file_to_context(callback)
    VibeContext.add_files_to_context(function(files)
      if files and #files > 0 then
        callback(files[1])
      end
    end)
  end

  function VibeContext.remove_file_from_context(context_files, callback)
    if #context_files == 0 then
      vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
      return
    end

    local telescope_pickers = require 'telescope.pickers'
    local telescope_finders = require 'telescope.finders'
    local telescope_conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    -- Create display entries for telescope
    local display_entries = {}
    local file_map = {}

    for _, file_path in ipairs(context_files) do
      local display_path = Utils.get_relative_path(file_path)
      table.insert(display_entries, display_path)
      file_map[display_path] = file_path
    end

    telescope_pickers
      .new({}, {
        prompt_title = 'Remove files from context (Tab to multi-select)',
        finder = telescope_finders.new_table {
          results = display_entries,
        },
        sorter = telescope_conf.generic_sorter {},
        previewer = require('telescope.previewers').new_buffer_previewer {
          title = 'File Preview',
          define_preview = function(self, entry)
            local filepath = file_map[entry.value]
            if not filepath or vim.fn.filereadable(filepath) ~= 1 then
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { 'File not readable or does not exist' })
              return
            end

            -- Read file content with error handling
            local content, err = FileCache.get_content(filepath)
            if not content then
              vim.api.nvim_buf_set_lines(
                self.state.bufnr,
                0,
                -1,
                false,
                { 'Error reading file: ' .. (err or 'Unknown error') }
              )
              return
            end

            -- Split content into lines and set in preview buffer
            local lines = vim.split(content, '\n')
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

            -- Set appropriate filetype for syntax highlighting
            local filetype = vim.filetype.match { filename = filepath }
            if filetype then
              vim.bo[self.state.bufnr].filetype = filetype
            end
          end,
        },
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local selections = {}
            local picker = action_state.get_current_picker(prompt_bufnr)

            -- Get multi-selected files
            local multi_selection = picker:get_multi_selection()
            if #multi_selection > 0 then
              for _, entry in ipairs(multi_selection) do
                table.insert(selections, file_map[entry.value])
              end
            else
              -- Get single selection if no multi-selection
              local entry = action_state.get_selected_entry()
              if entry then
                table.insert(selections, file_map[entry.value])
              end
            end

            actions.close(prompt_bufnr)

            if #selections > 0 then
              callback(selections)
            end
          end)

          return true
        end,
      })
      :find()
  end
end

-- =============================================================================
-- Vibe Chat: Manages the interactive chat window and sidebar layout
-- =============================================================================
local VibeChat = {}
do
  local messages_for_display = {}
  local VIBE_AUGROUP = vim.api.nvim_create_augroup('Vibe', { clear = true })

  VibeChat.state = {
    is_thinking = false,
    layout_active = false,
    output_win_id = nil,
    context_win_id = nil,
    input_win_id = nil,
    output_buf_id = nil,
    context_buf_id = nil,
    input_buf_id = nil,
    main_editor_win_id = nil,
    context_files = {},
  }

  -- Session management
  VibeChat.sessions = {
    current_session_id = nil,
    sessions_dir = vim.fn.stdpath 'data' .. '/vibe-sessions',
  }

  -- Initialize sessions directory
  function VibeChat.sessions.init()
    -- Create sessions directory if it doesn't exist
    if vim.fn.isdirectory(VibeChat.sessions.sessions_dir) == 0 then
      vim.fn.mkdir(VibeChat.sessions.sessions_dir, 'p')
    end
  end

  -- Start a new session or load existing one
  function VibeChat.sessions.start(session_name)
    -- Initialize sessions directory
    VibeChat.sessions.init()

    if not session_name or session_name == '' then
      -- Generate a timestamp-based session name if none provided
      session_name = os.date '%Y%m%d_%H%M%S'
    end

    -- Sanitize session name to be filesystem-friendly
    session_name = session_name:gsub('[^%w_%-]', '_')

    local session_file = VibeChat.sessions.sessions_dir .. '/' .. session_name .. '.json'
    VibeChat.sessions.current_session_id = session_name

    -- Reset the output buffer
    if VibeChat.state.output_buf_id and vim.api.nvim_buf_is_valid(VibeChat.state.output_buf_id) then
      vim.bo[VibeChat.state.output_buf_id].modifiable = true
      vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, 0, -1, false, {})

      -- Add welcome message
      vim.api.nvim_buf_set_lines(
        VibeChat.state.output_buf_id,
        -1,
        -1,
        false,
        vim.split('Welcome to Vibe Coding!\nModel: ' .. CONFIG.model, '\n')
      )
      vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, -1, -1, false, { '' })
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
      messages_for_display = session_data.messages or {}

      -- Restore context files
      VibeChat.state.context_files = session_data.context_files or {}
      VibeChat.update_context_buffer()

      -- Update the output buffer with the conversation history
      if VibeChat.state.output_buf_id and vim.api.nvim_buf_is_valid(VibeChat.state.output_buf_id) then
        -- Add session info
        vim.api.nvim_buf_set_lines(
          VibeChat.state.output_buf_id,
          -1,
          -1,
          false,
          vim.split('📂 Loaded session: ' .. session_name, '\n')
        )
        vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, -1, -1, false, { '' })

        -- Rebuild conversation history
        for _, msg in ipairs(messages_for_display) do
          if msg.role == 'user' then
            vim.api.nvim_buf_set_lines(
              VibeChat.state.output_buf_id,
              -1,
              -1,
              false,
              vim.split('👤 You:\n' .. msg.content, '\n')
            )
            vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, -1, -1, false, { '' })
          elseif msg.role == 'assistant' then
            vim.api.nvim_buf_set_lines(
              VibeChat.state.output_buf_id,
              -1,
              -1,
              false,
              vim.split('🤖 AI:\n' .. msg.content, '\n')
            )
            vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, -1, -1, false, { '' })
          end
        end

        vim.bo[VibeChat.state.output_buf_id].modifiable = false

        -- Scroll to bottom
        local win_id = VibeChat.state.output_win_id
        if win_id and vim.api.nvim_win_is_valid(win_id) then
          vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(VibeChat.state.output_buf_id), 0 })
        end
      end

      vim.notify('[Vibe] Loaded session: ' .. session_name, vim.log.levels.INFO)
    else
      -- Create new session
      -- Reset messages_for_display for new sessions
      messages_for_display = {}

      -- Clear context files for new session
      VibeChat.state.context_files = {}

      -- Add current buffer to context if it has a name
      local current_buf = vim.api.nvim_buf_get_name(
        VibeChat.state.main_editor_win_id and vim.api.nvim_win_get_buf(VibeChat.state.main_editor_win_id)
          or vim.api.nvim_get_current_buf()
      )
      if current_buf and current_buf ~= '' then
        table.insert(VibeChat.state.context_files, current_buf)
      end

      -- Update context buffer display
      VibeChat.update_context_buffer()

      -- Add session info to output
      if VibeChat.state.output_buf_id and vim.api.nvim_buf_is_valid(VibeChat.state.output_buf_id) then
        vim.api.nvim_buf_set_lines(
          VibeChat.state.output_buf_id,
          -1,
          -1,
          false,
          vim.split('📂 Started session: ' .. session_name, '\n')
        )
        vim.bo[VibeChat.state.output_buf_id].modifiable = false
      end

      VibeChat.sessions.save()
      vim.notify('[Vibe] Started new session: ' .. session_name, vim.log.levels.INFO)
    end

    return session_name
  end
  -- Save current session
  function VibeChat.sessions.save()
    if not VibeChat.sessions.current_session_id then
      return false
    end

    local session_file = VibeChat.sessions.sessions_dir .. '/' .. VibeChat.sessions.current_session_id .. '.json'
    local session_data = {
      messages = messages_for_display,
      context_files = VibeChat.state.context_files,
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
  function VibeChat.sessions.end_session()
    if not VibeChat.sessions.current_session_id then
      vim.notify('[Vibe] No active session to end.', vim.log.levels.WARN)
      return false
    end

    local session_name = VibeChat.sessions.current_session_id
    VibeChat.sessions.save()
    vim.notify('[Vibe] Saved and ended session: ' .. session_name, vim.log.levels.INFO)

    -- Don't clear the current_session_id so we keep saving to the same session
    return true
  end

  -- List all available sessions
  function VibeChat.sessions.list(callback)
    VibeChat.sessions.init()

    local sessions = {}
    local files = vim.fn.glob(VibeChat.sessions.sessions_dir .. '/*.json', false, true)

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
  -- Load a session interactively
  function VibeChat.sessions.load_interactive()
    VibeChat.sessions.init()

    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'
    local previewers = require 'telescope.previewers'

    -- Get session files with metadata
    local files = vim.fn.glob(VibeChat.sessions.sessions_dir .. '/*.json', false, true)
    if #files == 0 then
      vim.notify('[Vibe] No saved sessions found.', vim.log.levels.INFO)
      return
    end

    local sessions_with_data = {}
    for _, file in ipairs(files) do
      local session_name = vim.fn.fnamemodify(file, ':t:r')
      local mod_time = vim.fn.getftime(file)
      local mod_date = os.date('%Y-%m-%d %H:%M:%S', mod_time)

      -- Try to read session data for preview
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

    -- Sort by modification time (most recent first)
    table.sort(sessions_with_data, function(a, b)
      return a.time > b.time
    end)

    pickers
      .new({}, {
        prompt_title = 'Select Session to Load',
        finder = finders.new_table {
          results = sessions_with_data,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.name,
            }
          end,
        },
        previewer = previewers.new_buffer_previewer {
          title = 'Session Preview',
          define_preview = function(self, entry)
            local session = entry.value
            local lines = {}

            -- Session info
            table.insert(lines, '📂 Session: ' .. session.name)
            table.insert(lines, '📅 Modified: ' .. session.date)
            table.insert(lines, '')

            if session.data then
              -- Context files
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

              -- Messages
              if session.data.messages and #session.data.messages > 0 then
                table.insert(lines, '💬 Messages (' .. #session.data.messages .. '):')
                table.insert(lines, '')

                -- Show last few messages
                local start_idx = math.max(1, #session.data.messages - 4)
                for i = start_idx, #session.data.messages do
                  local msg = session.data.messages[i]
                  if msg.role == 'user' then
                    table.insert(lines, '👤 You:')
                    -- Show first few lines of user message
                    local content_lines = vim.split(msg.content, '\n')
                    for j = 1, math.min(3, #content_lines) do
                      table.insert(lines, '  ' .. content_lines[j])
                    end
                    if #content_lines > 3 then
                      table.insert(lines, '  ...')
                    end
                  elseif msg.role == 'assistant' then
                    table.insert(lines, '🤖 AI:')
                    -- Show first few lines of AI response
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

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)

            if entry and entry.value then
              -- Open chat window if not already open
              if not VibeChat.state.layout_active then
                VibeChat.open_chat_window()
              end

              -- Load the selected session
              VibeChat.sessions.start(entry.value.name)
            end
          end)

          return true
        end,
      })
      :find()
  end

  -- Delete a session interactively
  function VibeChat.sessions.delete_interactive()
    VibeChat.sessions.list(function(sessions)
      if #sessions == 0 then
        return
      end

      vim.ui.select(sessions, {
        prompt = 'Select a session to delete:',
      }, function(choice)
        if not choice then
          return
        end

        local session_file = VibeChat.sessions.sessions_dir .. '/' .. choice .. '.json'

        vim.ui.input({
          prompt = "Are you sure you want to delete session '" .. choice .. "'? (y/N): ",
        }, function(input)
          if input and input:lower() == 'y' then
            vim.fn.delete(session_file)
            vim.notify('[Vibe] Deleted session: ' .. choice, vim.log.levels.INFO)

            -- If we deleted the current session, clear the session ID
            if VibeChat.sessions.current_session_id == choice then
              VibeChat.sessions.current_session_id = nil
            end
          end
        end)
      end)
    end)
  end

  function VibeChat.sessions.rename_interactive()
    -- If no active session, notify and return
    if not VibeChat.sessions.current_session_id then
      vim.notify('[Vibe] No active session to rename.', vim.log.levels.WARN)
      return
    end

    local current_name = VibeChat.sessions.current_session_id

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
      local new_file = VibeChat.sessions.sessions_dir .. '/' .. new_name .. '.json'
      if vim.fn.filereadable(new_file) == 1 then
        vim.ui.input({
          prompt = "Session '" .. new_name .. "' already exists. Overwrite? (y/N): ",
        }, function(input)
          if not input or input:lower() ~= 'y' then
            vim.notify('[Vibe] Session rename cancelled.', vim.log.levels.INFO)
            return
          end
          VibeChat.sessions.perform_rename(current_name, new_name)
        end)
      else
        VibeChat.sessions.perform_rename(current_name, new_name)
      end
    end)
  end

  -- Helper function to actually perform the rename operation
  function VibeChat.sessions.perform_rename(old_name, new_name)
    local old_file = VibeChat.sessions.sessions_dir .. '/' .. old_name .. '.json'
    local new_file = VibeChat.sessions.sessions_dir .. '/' .. new_name .. '.json'

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
      VibeChat.sessions.current_session_id = new_name

      -- Update the output buffer with the new session name
      VibeChat.append_to_output('📂 Renamed session: ' .. old_name .. ' → ' .. new_name)

      vim.notify('[Vibe] Session renamed: ' .. old_name .. ' → ' .. new_name, vim.log.levels.INFO)
    else
      vim.notify('[Vibe] Failed to rename session.', vim.log.levels.ERROR)
    end
  end

  function VibeChat.sessions.get_most_recent()
    VibeChat.sessions.init()

    local files = vim.fn.glob(VibeChat.sessions.sessions_dir .. '/*.json', false, true)
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
  -- Accessor function to safely get messages from other modules
  function VibeChat.get_messages()
    return messages_for_display
  end

  function VibeChat.update_context_buffer()
    local buf_id = VibeChat.state.context_buf_id
    if buf_id == nil or not vim.api.nvim_buf_is_valid(buf_id) then
      return
    end

    local display_lines = { '--- Context Files ---' }
    for _, file_path in ipairs(VibeChat.state.context_files) do
      -- Check if file still exists before displaying
      if vim.fn.filereadable(file_path) == 1 then
        local display_path = Utils.get_relative_path(file_path)
        table.insert(display_lines, display_path)
      else
        -- Mark non-existent files with warning
        table.insert(display_lines, '⚠️  ' .. file_path .. ' (not found)')
      end
    end

    vim.bo[buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, display_lines)
    vim.bo[buf_id].modifiable = false
  end

  function VibeChat.cycle_focus()
    if not VibeChat.state.layout_active then
      return
    end
    local current_win = vim.api.nvim_get_current_win()
    local state = VibeChat.state

    if current_win == state.output_win_id then
      vim.api.nvim_set_current_win(state.context_win_id)
    elseif current_win == state.context_win_id then
      vim.api.nvim_set_current_win(state.input_win_id)
    elseif current_win == state.input_win_id then
      vim.api.nvim_set_current_win(state.output_win_id)
    end
  end

  function VibeChat.cycle_focus_reverse()
    if not VibeChat.state.layout_active then
      return
    end
    local current_win = vim.api.nvim_get_current_win()
    local state = VibeChat.state

    if current_win == state.input_win_id then
      vim.api.nvim_set_current_win(state.context_win_id)
    elseif current_win == state.context_win_id then
      vim.api.nvim_set_current_win(state.output_win_id)
    elseif current_win == state.output_win_id then
      vim.api.nvim_set_current_win(state.input_win_id)
    end
  end

  function VibeChat.open_chat_window()
    if
      VibeChat.state.layout_active
      and VibeChat.state.input_win_id
      and vim.api.nvim_win_is_valid(VibeChat.state.input_win_id)
    then
      vim.api.nvim_set_current_win(VibeChat.state.input_win_id)
      return
    elseif VibeChat.state.layout_active then
      VibeChat.close_layout()
    end

    -- Clean up any existing buffers with the same names before creating new ones
    local function cleanup_buffer_by_name(name)
      local bufnr = vim.fn.bufnr(name)
      if bufnr ~= -1 then
        vim.cmd('silent! bwipeout! ' .. bufnr)
      end
    end

    -- Clean up potential existing buffers
    cleanup_buffer_by_name 'vibe-output'
    cleanup_buffer_by_name 'vibe-context'
    cleanup_buffer_by_name 'vibe-input'

    VibeChat.state.main_editor_win_id = vim.api.nvim_get_current_win()

    -- Store original equalalways setting and disable it to prevent auto-resizing
    VibeChat.state.original_equalalways = vim.o.equalalways
    vim.o.equalalways = false

    -- Navigate to rightmost window before creating split
    vim.cmd 'wincmd l'

    -- 1. Create sidebar and get its total available height
    vim.cmd 'vsplit'
    vim.cmd('vertical resize ' .. CONFIG.sidebar_width)
    local sidebar_height = vim.api.nvim_win_get_height(0)

    -- 2. Create horizontal panes
    vim.cmd 'split'
    vim.cmd 'split'

    -- 3. Capture all window IDs
    VibeChat.state.input_win_id = vim.api.nvim_get_current_win()
    vim.cmd 'wincmd k'
    VibeChat.state.context_win_id = vim.api.nvim_get_current_win()
    vim.cmd 'wincmd k'
    VibeChat.state.output_win_id = vim.api.nvim_get_current_win()

    -- 4. Explicitly calculate and set all heights
    local input_height = math.max(CONFIG.min_input_height, math.floor(sidebar_height * CONFIG.input_height_ratio))
    local context_height = math.max(CONFIG.min_context_height, math.floor(sidebar_height * CONFIG.context_height_ratio))
    local output_height = sidebar_height - input_height - context_height

    vim.api.nvim_win_set_height(VibeChat.state.output_win_id, output_height)
    vim.api.nvim_win_set_height(VibeChat.state.context_win_id, context_height)
    vim.api.nvim_win_set_height(VibeChat.state.input_win_id, input_height)

    -- 4.1 Set window options to prevent automatic resizing
    -- Fix width for all chat windows to maintain consistent sidebar width
    vim.api.nvim_win_set_width(VibeChat.state.output_win_id, CONFIG.sidebar_width)
    vim.api.nvim_win_set_width(VibeChat.state.context_win_id, CONFIG.sidebar_width)
    vim.api.nvim_win_set_width(VibeChat.state.input_win_id, CONFIG.sidebar_width)

    -- Set window options to prevent equalize on close
    vim.wo[VibeChat.state.output_win_id].winfixwidth = true
    vim.wo[VibeChat.state.context_win_id].winfixwidth = true
    vim.wo[VibeChat.state.input_win_id].winfixwidth = true
    vim.wo[VibeChat.state.output_win_id].winfixheight = true
    vim.wo[VibeChat.state.context_win_id].winfixheight = true
    vim.wo[VibeChat.state.input_win_id].winfixheight = true

    -- 5. Create and configure buffers
    VibeChat.state.output_buf_id = vim.api.nvim_create_buf(false, true)
    VibeChat.state.context_buf_id = vim.api.nvim_create_buf(false, true)
    VibeChat.state.input_buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(VibeChat.state.output_win_id, VibeChat.state.output_buf_id)
    vim.api.nvim_win_set_buf(VibeChat.state.context_win_id, VibeChat.state.context_buf_id)
    vim.api.nvim_win_set_buf(VibeChat.state.input_win_id, VibeChat.state.input_buf_id)

    vim.bo[VibeChat.state.output_buf_id].filetype, vim.bo[VibeChat.state.output_buf_id].modifiable, vim.bo[VibeChat.state.output_buf_id].buflisted =
      'markdown', true, false
    vim.bo[VibeChat.state.context_buf_id].modifiable, vim.bo[VibeChat.state.context_buf_id].buflisted = false, false
    vim.bo[VibeChat.state.input_buf_id].buflisted = false
    vim.api.nvim_buf_set_name(VibeChat.state.output_buf_id, 'vibe-output')
    vim.api.nvim_buf_set_name(VibeChat.state.context_buf_id, 'vibe-context')
    vim.api.nvim_buf_set_name(VibeChat.state.input_buf_id, 'vibe-input')
    -- Enable line wrapping in output window
    vim.wo[VibeChat.state.output_win_id].wrap = true

    -- 6. Set keymaps
    local function create_keymap_opts(buf_id)
      return { noremap = true, silent = true, buffer = buf_id }
    end

    vim.keymap.set('i', '<C-s>', function()
      VibeChat.send_message()
    end, create_keymap_opts(VibeChat.state.input_buf_id))
    vim.keymap.set('n', '<CR>', function()
      VibeChat.send_message()
    end, create_keymap_opts(VibeChat.state.input_buf_id))

    for _, buf_id in ipairs { VibeChat.state.input_buf_id, VibeChat.state.output_buf_id, VibeChat.state.context_buf_id } do
      vim.keymap.set('n', 'q', '<cmd>VibeClose<CR>', create_keymap_opts(buf_id))
      vim.keymap.set('n', '<Tab>', function()
        VibeChat.cycle_focus()
      end, create_keymap_opts(buf_id))
      vim.keymap.set('n', '<S-Tab>', function()
        VibeChat.cycle_focus_reverse()
      end, create_keymap_opts(buf_id))
    end

    -- Context-specific keymaps for removing files
    vim.keymap.set('n', 'dd', function()
      VibeChat.remove_single_file_from_context()
    end, create_keymap_opts(VibeChat.state.context_buf_id))

    vim.keymap.set('v', 'dd', function()
      VibeChat.remove_selected_files_from_context()
    end, create_keymap_opts(VibeChat.state.context_buf_id))

    -- Output window specific keymap for diffing code blocks
    vim.keymap.set('n', 'dv', function()
      VibeChat.diff_code_block_at_cursor()
    end, create_keymap_opts(VibeChat.state.output_buf_id))

    -- Initialize sessions directory
    VibeChat.sessions.init()

    -- Add welcome message to output buffer
    vim.api.nvim_buf_set_lines(
      VibeChat.state.output_buf_id,
      0,
      -1,
      false,
      vim.split(
        'Welcome to Vibe Coding!\nModel: ' .. CONFIG.model .. '\nSubmit with Ctrl+s (Insert) or Enter (Normal).',
        '\n'
      )
    )

    -- Load session or create new one
    local session_to_load

    if VibeChat.sessions.current_session_id then
      -- We have an active session ID, use it
      session_to_load = VibeChat.sessions.current_session_id
    else
      -- Try to get most recent session
      session_to_load = VibeChat.sessions.get_most_recent()
      if not session_to_load then
        -- No previous sessions, create timestamp-based name
        session_to_load = os.date '%Y%m%d_%H%M%S'
      end
    end

    -- Now actually load the session (this will populate messages and context)
    if session_to_load then
      VibeChat.sessions.start(session_to_load)
    end

    -- Add current buffer to context if it exists
    local initial_buf_name = ''
    if VibeChat.state.main_editor_win_id and vim.api.nvim_win_is_valid(VibeChat.state.main_editor_win_id) then
      local buf_id = vim.api.nvim_win_get_buf(VibeChat.state.main_editor_win_id)
      initial_buf_name = vim.api.nvim_buf_get_name(buf_id)
    end

    -- Only add to context files if it's not already there and is a valid file
    if initial_buf_name and initial_buf_name ~= '' then
      local already_in_context = false
      for _, path in ipairs(VibeChat.state.context_files) do
        if path == initial_buf_name then
          already_in_context = true
          break
        end
      end

      if not already_in_context then
        table.insert(VibeChat.state.context_files, initial_buf_name)
        VibeChat.sessions.save() -- Save the updated context
      end

      VibeChat.update_context_buffer()
    end

    VibeChat.state.layout_active = true
    vim.api.nvim_set_current_win(VibeChat.state.input_win_id)
    vim.cmd 'startinsert'

    if VibeChat.state.input_win_id and vim.api.nvim_win_is_valid(VibeChat.state.input_win_id) then
      vim.api.nvim_create_autocmd('WinClosed', {
        group = VIBE_AUGROUP,
        pattern = tostring(VibeChat.state.input_win_id),
        callback = function()
          vim.schedule(VibeChat.close_layout)
        end,
      })
    end
  end

  function VibeChat.close_layout()
    if not VibeChat.state.layout_active then
      return
    end

    -- Save current session before closing
    if VibeChat.sessions.current_session_id then
      VibeChat.sessions.save()
    end

    local to_close = { VibeChat.state.output_win_id, VibeChat.state.context_win_id, VibeChat.state.input_win_id }
    VibeChat.state.layout_active = false
    VibeChat.state.context_files = {}

    -- Restore original equalalways setting
    if VibeChat.state.original_equalalways ~= nil then
      vim.o.equalalways = VibeChat.state.original_equalalways
      VibeChat.state.original_equalalways = nil
    end

    vim.api.nvim_clear_autocmds { group = VIBE_AUGROUP }
    for _, win_id in ipairs(to_close) do
      if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
      end
    end
  end

  function VibeChat.append_to_output(text)
    local buf_id = VibeChat.state.output_buf_id
    if buf_id == nil or not vim.api.nvim_buf_is_valid(buf_id) then
      return
    end
    vim.bo[buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, vim.split(text, '\n', { trimempty = true }))
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, { '' })
    vim.bo[buf_id].modifiable = false
    local win_id = VibeChat.state.output_win_id
    if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(buf_id), 0 })
    end
  end

  function VibeChat.send_message()
    -- Enhanced race condition protection
    if VibeChat.state.is_thinking then
      vim.notify('[Vibe] Please wait for the AI to finish responding.', vim.log.levels.WARN)
      return
    end

    local input_buf = VibeChat.state.input_buf_id
    if input_buf == nil or not vim.api.nvim_buf_is_valid(input_buf) then
      vim.notify('[Vibe] Input buffer is not valid.', vim.log.levels.ERROR)
      return
    end

    local user_input = table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), '\n')
    if user_input == '' or user_input:match '^%s*$' then
      vim.notify('[Vibe] Please enter a message.', vim.log.levels.WARN)
      return
    end

    -- Set thinking state immediately to prevent race conditions
    VibeChat.state.is_thinking = true

    vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
    VibeChat.append_to_output('👤 You:\n' .. user_input)
    table.insert(messages_for_display, { role = 'user', content = user_input })
    VibeChat.append_to_output '🤔 AI is thinking...'

    -- In your send_message() function, replace the messages_for_api initialization with:
    local messages_for_api = {
      {
        role = 'system',
        content = '',  -- load from ./prompts/unified-diffs.md  AI!
      },
    }

    for _, file_path in ipairs(VibeChat.state.context_files) do
      local content, err = FileCache.get_content(file_path)
      if content then
        local context_msg = 'CONTEXT from file `'
          .. vim.fn.fnamemodify(file_path, ':p')
          .. '`:\n\n```\n'
          .. content
          .. '\n```'
        table.insert(messages_for_api, { role = 'user', content = context_msg })
      else
        vim.notify('[Vibe] Failed to read context file ' .. file_path .. ': ' .. err, vim.log.levels.WARN)
      end
    end
    table.insert(messages_for_api, { role = 'user', content = user_input })

    -- Set timeout to prevent getting stuck
    local timeout_timer = vim.fn.timer_start(120000, function()
      if VibeChat.state.is_thinking then
        VibeChat.state.is_thinking = false
        -- Remove thinking message
        if VibeChat.state.layout_active then
          local output_lines = vim.api.nvim_buf_get_lines(VibeChat.state.output_buf_id, 0, -1, false)
          for i = #output_lines, 1, -1 do
            if string.find(output_lines[i], '🤔 AI is thinking...') then
              vim.bo[VibeChat.state.output_buf_id].modifiable = true
              vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, i - 1, i, false, {})
              vim.bo[VibeChat.state.output_buf_id].modifiable = false
              break
            end
          end
          VibeChat.append_to_output '❌ Request timed out after 2 minutes'
        end
      end
    end)

    local streaming_started = false

    VibeAPI.get_completion(messages_for_api, function(response_text, err)
      -- Cancel timeout timer
      vim.fn.timer_stop(timeout_timer)

      -- ALWAYS reset thinking state regardless of success/failure
      VibeChat.state.is_thinking = false

      if not VibeChat.state.layout_active then
        return
      end

      if err then
        -- Remove thinking message and show error
        local output_lines = vim.api.nvim_buf_get_lines(VibeChat.state.output_buf_id, 0, -1, false)
        for i = #output_lines, 1, -1 do
          if string.find(output_lines[i], '🤔 AI is thinking...') then
            vim.bo[VibeChat.state.output_buf_id].modifiable = true
            vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, i - 1, i, false, {})
            vim.bo[VibeChat.state.output_buf_id].modifiable = false
            break
          end
        end
        VibeChat.append_to_output('❌ Error: ' .. err)
      else
        table.insert(messages_for_display, { role = 'assistant', content = response_text })
      end

      -- Save session after each message exchange
      if VibeChat.sessions.current_session_id then
        VibeChat.sessions.save()
      end
    end, function(chunk)
      -- Stream callback - called for each chunk
      if not VibeChat.state.layout_active then
        return
      end

      -- Additional safety check to prevent stuck state
      if not VibeChat.state.is_thinking then
        return
      end

      local output_buf = VibeChat.state.output_buf_id
      if output_buf == nil or not vim.api.nvim_buf_is_valid(output_buf) then
        return
      end
      if not streaming_started then
        -- Remove "thinking" message and start AI response
        vim.bo[output_buf].modifiable = true
        local lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
        for i = #lines, 1, -1 do
          if string.find(lines[i], '🤔 AI is thinking...') then
            -- Replace the "thinking" line with the start of the AI response
            vim.api.nvim_buf_set_lines(output_buf, i - 1, i, false, { '🤖 AI:' })
            break
          end
        end
        vim.bo[output_buf].modifiable = false
        streaming_started = true
      end

      -- Append the streaming chunk directly to the buffer
      vim.bo[output_buf].modifiable = true
      -- Split the chunk by newlines to handle multi-line chunks correctly
      local chunk_lines = vim.split(chunk, '\n', { plain = true })

      -- Get the current last line to append the first part of the chunk
      local buffer_lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
      local last_line_index = #buffer_lines

      if last_line_index > 0 then
        -- Append the first part of the chunk to the existing last line
        buffer_lines[last_line_index] = buffer_lines[last_line_index] .. chunk_lines[1]

        -- If the chunk had newlines, add the rest of the chunk parts as new lines
        if #chunk_lines > 1 then
          for i = 2, #chunk_lines do
            table.insert(buffer_lines, chunk_lines[i])
          end
        end

        -- Replace the content starting from the original last line
        vim.api.nvim_buf_set_lines(
          output_buf,
          last_line_index - 1,
          -1,
          false,
          { unpack(buffer_lines, last_line_index) }
        )
      end

      vim.bo[output_buf].modifiable = false

      -- Auto-scroll to bottom
      local win_id = vim.fn.bufwinid(output_buf)
      if win_id ~= -1 then
        local final_line_count = vim.api.nvim_buf_line_count(output_buf)
        vim.api.nvim_win_set_cursor(win_id, { final_line_count, 0 })
      end
    end)
  end

  function VibeChat.add_context_to_chat()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end
    VibeContext.add_files_to_context(function(filepaths)
      if filepaths and #filepaths > 0 then
        local added_files = {}
        local skipped_files = {}

        for _, filepath in ipairs(filepaths) do
          local already_exists = false
          for _, existing_path in ipairs(VibeChat.state.context_files) do
            if existing_path == filepath then
              already_exists = true
              table.insert(skipped_files, vim.fn.fnamemodify(filepath, ':t'))
              break
            end
          end

          if not already_exists then
            table.insert(VibeChat.state.context_files, filepath)
            table.insert(added_files, vim.fn.fnamemodify(filepath, ':t'))
          end
        end

        VibeChat.update_context_buffer()

        if #added_files > 0 then
          local files_str = table.concat(added_files, '`, `')
          VibeChat.append_to_output('Added `' .. files_str .. '` to context.')
        end

        if #skipped_files > 0 then
          local skipped_str = table.concat(skipped_files, '`, `')
          vim.notify('[Vibe] Files already in context: `' .. skipped_str .. '`', vim.log.levels.INFO)
        end
      end
    end)
  end

  function VibeChat.remove_context_from_chat()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end

    VibeContext.remove_file_from_context(VibeChat.state.context_files, function(filepaths)
      if filepaths and #filepaths > 0 then
        local removed_files = {}
        local not_found_files = {}

        for _, filepath in ipairs(filepaths) do
          local found = false
          for i = #VibeChat.state.context_files, 1, -1 do
            if VibeChat.state.context_files[i] == filepath then
              table.remove(VibeChat.state.context_files, i)
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
          VibeChat.update_context_buffer()
          local files_str = table.concat(removed_files, '`, `')
          VibeChat.append_to_output('Removed `' .. files_str .. '` from context.')

          -- Save session after context change
          if VibeChat.sessions.current_session_id then
            VibeChat.sessions.save()
          end
        end

        if #not_found_files > 0 then
          local not_found_str = table.concat(not_found_files, '`, `')
          vim.notify('[Vibe] Files not found in context: `' .. not_found_str .. '`', vim.log.levels.WARN)
        end
      end
    end)
  end

  function VibeChat.add_current_buffer_to_context()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end

    local filepath = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())

    if filepath == '' then
      vim.notify('[Vibe] Cannot add an unnamed buffer to context.', vim.log.levels.WARN)
      return
    end

    for _, existing_path in ipairs(VibeChat.state.context_files) do
      if existing_path == filepath then
        vim.notify('[Vibe] File already in context.', vim.log.levels.INFO)
        return
      end
    end

    table.insert(VibeChat.state.context_files, filepath)
    VibeChat.update_context_buffer()
    VibeChat.append_to_output('Added `' .. vim.fn.fnamemodify(filepath, ':t') .. '` to context.')
  end

  function VibeChat.clear_context()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end

    if #VibeChat.state.context_files == 0 then
      vim.notify('[Vibe] Context is already empty.', vim.log.levels.INFO)
      return
    end

    vim.ui.input({
      prompt = 'Clear all context files? (y/N): ',
    }, function(input)
      if input and input:lower() == 'y' then
        local count = #VibeChat.state.context_files
        VibeChat.state.context_files = {}
        VibeChat.update_context_buffer()
        VibeChat.append_to_output('Cleared ' .. count .. ' files from context.')

        -- Save session after context change
        if VibeChat.sessions.current_session_id then
          VibeChat.sessions.save()
        end
      end
    end)
  end

  function VibeChat.remove_single_file_from_context()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end

    if #VibeChat.state.context_files == 0 then
      vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
      return
    end

    -- Get the current line number in the context window
    local current_win = vim.api.nvim_get_current_win()
    if current_win ~= VibeChat.state.context_win_id then
      vim.notify('[Vibe] Must be in context window to remove files', vim.log.levels.WARN)
      return
    end

    local cursor_line = vim.api.nvim_win_get_cursor(current_win)[1]

    -- Adjust line index to match context_files index (skip header)
    local file_index = cursor_line - 1 -- Skip the header line which starts at 1, files start from index 0
    if file_index < 1 or file_index > #VibeChat.state.context_files then
      vim.notify('[Vibe] Invalid line selection', vim.log.levels.WARN)
      return
    end

    local file_to_remove = VibeChat.state.context_files[file_index]
    if file_to_remove then
      table.remove(VibeChat.state.context_files, file_index)
      VibeChat.update_context_buffer()
      VibeChat.append_to_output('Removed `' .. vim.fn.fnamemodify(file_to_remove, ':t') .. '` from context.')

      -- Save session after context change
      if VibeChat.sessions.current_session_id then
        VibeChat.sessions.save()
      end
    else
      vim.notify('[Vibe] Could not find file to remove', vim.log.levels.WARN)
    end
  end

  function VibeChat.remove_selected_files_from_context()
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end

    if #VibeChat.state.context_files == 0 then
      vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
      return
    end

    -- Get the current window and ensure we're in the context window
    local current_win = vim.api.nvim_get_current_win()
    if current_win ~= VibeChat.state.context_win_id then
      vim.notify('[Vibe] Must be in context window to remove files', vim.log.levels.WARN)
      return
    end

    -- Get visual selection range
    local start_line = vim.fn.line "'<"
    local end_line = vim.fn.line "'>"
    local context_lines = vim.api.nvim_buf_get_lines(VibeChat.state.context_buf_id, 0, -1, false)

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
          for _, filepath in ipairs(VibeChat.state.context_files) do
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
      for j, filepath in ipairs(VibeChat.state.context_files) do
        if filepath == files_to_remove[i] then
          table.remove(VibeChat.state.context_files, j)
          break
        end
      end
    end

    if #removed_filenames > 0 then
      VibeChat.update_context_buffer()
      local files_str = table.concat(removed_filenames, '`, `')
      VibeChat.append_to_output('Removed `' .. files_str .. '` from context.')

      -- Save session after context change
      if VibeChat.sessions.current_session_id then
        VibeChat.sessions.save()
      end
    else
      vim.notify('[Vibe] No valid files selected for removal', vim.log.levels.WARN)
    end
  end

  -- Diff code block at cursor with buffer
  function VibeChat.diff_code_block_at_cursor()
    if not VibeChat.state.layout_active or not VibeChat.state.output_buf_id then
      vim.notify('[Vibe] Chat output window not available', vim.log.levels.WARN)
      return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor[1]
    local lines = vim.api.nvim_buf_get_lines(VibeChat.state.output_buf_id, 0, -1, false)

    -- Find code block boundaries around cursor
    local code_start, code_end = nil, nil
    local lang = nil

    -- Search backwards for opening fence
    for i = current_line, 1, -1 do
      local line = lines[i]
      if line then
        local fence_lang = string.match(line, '^```(%w*)')
        if fence_lang then
          code_start = i + 1
          lang = fence_lang ~= '' and fence_lang or nil
          break
        end
      end
    end

    -- Search forwards for closing fence
    if code_start then
      for i = current_line, #lines do
        local line = lines[i]
        if line and string.match(line, '^```%s*$') then
          code_end = i - 1
          break
        end
      end
    end

    if not code_start or not code_end or code_start > code_end then
      vim.notify('[Vibe] No code block found at cursor position', vim.log.levels.WARN)
      return
    end

    -- Extract code block content
    local code_lines = {}
    for i = code_start, code_end do
      table.insert(code_lines, lines[i] or '')
    end
    local code_content = table.concat(code_lines, '\n')

    if #code_content == 0 then
      vim.notify('[Vibe] Empty code block', vim.log.levels.WARN)
      return
    end

    -- Get the original buffer from main editor
    if not VibeChat.state.main_editor_win_id or not vim.api.nvim_win_is_valid(VibeChat.state.main_editor_win_id) then
      vim.notify('[Vibe] Original editor window not available', vim.log.levels.WARN)
      return
    end

    local main_buf = vim.api.nvim_win_get_buf(VibeChat.state.main_editor_win_id)
    local main_content = table.concat(vim.api.nvim_buf_get_lines(main_buf, 0, -1, false), '\n')

    -- Create temp buffers for diff
    local original_buf = vim.api.nvim_create_buf(false, true)
    local suggested_buf = vim.api.nvim_create_buf(false, true)

    -- Set content
    vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, vim.split(main_content, '\n'))
    vim.api.nvim_buf_set_lines(suggested_buf, 0, -1, false, code_lines)

    -- Set filetype if language detected
    local main_ft = vim.bo[main_buf].filetype
    if lang and lang ~= '' then
      vim.bo[original_buf].filetype = lang
      vim.bo[suggested_buf].filetype = lang
    elseif main_ft and main_ft ~= '' then
      vim.bo[original_buf].filetype = main_ft
      vim.bo[suggested_buf].filetype = main_ft
    end

    -- Set buffer names
    vim.api.nvim_buf_set_name(original_buf, 'Original Buffer')
    vim.api.nvim_buf_set_name(suggested_buf, 'AI Suggestion')

    -- Open diff in new tab
    vim.cmd 'tabnew'
    local tab_id = vim.api.nvim_get_current_tabpage()

    -- Set up diff layout
    vim.api.nvim_win_set_buf(0, original_buf)
    vim.cmd 'vsplit'
    vim.api.nvim_win_set_buf(0, suggested_buf)

    -- Enable diff mode
    vim.cmd 'diffthis'
    vim.cmd 'wincmd h'
    vim.cmd 'diffthis'

    -- Add keymaps for the diff tab
    local function create_diff_keymap_opts(buf)
      return { noremap = true, silent = true, buffer = buf }
    end

    -- Close diff keymap
    vim.keymap.set('n', 'q', function()
      vim.cmd 'tabclose'
    end, create_diff_keymap_opts(original_buf))

    vim.keymap.set('n', 'q', function()
      vim.cmd 'tabclose'
    end, create_diff_keymap_opts(suggested_buf))

    -- Accept suggestion keymap
    vim.keymap.set('n', '<leader>da', function()
      -- Copy suggested content to main buffer
      local suggested_lines = vim.api.nvim_buf_get_lines(suggested_buf, 0, -1, false)
      vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, suggested_lines)

      -- Focus main window and close diff
      vim.api.nvim_set_current_win(VibeChat.state.main_editor_win_id)
      vim.cmd('tabclose ' .. tab_id)
      vim.notify('[Vibe] Applied AI suggestion to buffer', vim.log.levels.INFO)
    end, create_diff_keymap_opts(original_buf))

    vim.keymap.set('n', '<leader>da', function()
      -- Copy suggested content to main buffer
      local suggested_lines = vim.api.nvim_buf_get_lines(suggested_buf, 0, -1, false)
      vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, suggested_lines)

      -- Focus main window and close diff
      vim.api.nvim_set_current_win(VibeChat.state.main_editor_win_id)
      vim.cmd('tabclose ' .. tab_id)
      vim.notify('[Vibe] Applied AI suggestion to buffer', vim.log.levels.INFO)
    end, create_diff_keymap_opts(suggested_buf))

    vim.notify('[Vibe] Code block diff opened. Use q to close, <leader>da to accept suggestion', vim.log.levels.INFO)
  end
end

-- =============================================================================
-- Vibe Diff: Shows diff between AI response and main editor window
-- =============================================================================
local VibeDiff = {}
do
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

  function VibeDiff.get_relevant_code_block()
    local messages = VibeChat.get_messages()
    local last_ai_message = nil

    for i = #messages, 1, -1 do
      if messages[i].role == 'assistant' then
        last_ai_message = messages[i].content
        break
      end
    end

    if not last_ai_message then
      return nil, 'No AI response found'
    end

    local code_blocks = VibeDiff.extract_code_blocks(last_ai_message)
    if #code_blocks == 0 then
      return nil, 'No code blocks found in AI response'
    end

    local main_win = VibeChat.state.main_editor_win_id
    if not main_win or not vim.api.nvim_win_is_valid(main_win) then
      return code_blocks[#code_blocks], nil
    end

    local main_buf = vim.api.nvim_win_get_buf(main_win)
    local main_filetype = vim.bo[main_buf].filetype

    for i = #code_blocks, 1, -1 do
      local block = code_blocks[i]
      if block.language and block.language == main_filetype then
        return block, nil
      end
    end

    return code_blocks[#code_blocks], nil
  end

  function VibeDiff.cleanup_diff_buffers()
    for buf_id, _ in pairs(VibeDiff.active_diffs) do
      if vim.api.nvim_buf_is_valid(buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
      end
    end
    VibeDiff.active_diffs = {}
  end

  function VibeDiff.show()
    local code_block, err = VibeDiff.get_relevant_code_block()
    if not code_block then
      vim.notify('[Vibe] ' .. (err or 'No suitable code block found'), vim.log.levels.WARN)
      return
    end

    local main_win = VibeChat.state.main_editor_win_id
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

    vim.keymap.set('n', '<leader>da', function()
      vim.cmd '%diffget'
      vim.cmd 'write'
      VibeDiff.cleanup_diff_buffers()
      vim.cmd 'diffoff!'
    end, { buffer = main_buf, desc = 'Accept all AI suggestions' })

    vim.notify(
      '[Vibe] Diff opened. Use do/dp for changes, <leader>da to accept all, <leader>dq to close',
      vim.log.levels.INFO
    )
  end
end

-- =============================================================================
-- Vibe Patcher: Applies unified diffs from AI responses
-- =============================================================================
local VibePatcher = {}
do
  --- Parses a single unified diff block.
  -- @param diff_content The string content of the diff.
  -- @return A table with parsed diff info, or nil and an error message.
  function VibePatcher.parse_diff(diff_content)
    local lines = vim.split(diff_content, '\n', { plain = true })
    local diff = { hunks = {} }

    if #lines < 3 then
      return nil, 'Diff content is too short'
    end

    diff.old_path = lines[1]:match '^---%s+(.*)$'
    diff.new_path = lines[2]:match '^%+%+%+%s+(.*)$'

    if not diff.old_path or not diff.new_path then
      return nil, 'Could not parse file paths from diff header'
    end

    diff.old_path = diff.old_path:match '^a/(.*)' or diff.old_path
    diff.new_path = diff.new_path:match '^b/(.*)' or diff.new_path

    if diff.old_path:match '%s' then
      diff.old_path = diff.old_path:gsub('%s+$', '')
    end
    if diff.new_path:match '%s' then
      diff.new_path = diff.new_path:gsub('%s+$', '')
    end

    local current_hunk = nil
    for i = 3, #lines do
      local line = lines[i]
      if line:match '^@@' then
        if current_hunk and #current_hunk.lines > 0 then
          table.insert(diff.hunks, current_hunk)
        end
        current_hunk = { lines = {} }
      elseif current_hunk and (line:match '^[-+]') then
        table.insert(current_hunk.lines, line)
      end
    end
    if current_hunk and #current_hunk.lines > 0 then
      table.insert(diff.hunks, current_hunk)
    end

    if #diff.hunks == 0 then
      return nil, 'Diff contains no changes'
    end

    return diff, nil
  end

  --- Extracts diff content from raw text that may not be in code blocks.
  -- @param text The raw text content to search for diffs.
  -- @return string|nil: The extracted diff content, or nil if none found.
  function VibePatcher.extract_diff_from_text(text)
    local lines = vim.split(text, '\n', { plain = true })
    local diff_lines = {}
    local in_diff = false
    local found_diff_header = false

    for _, line in ipairs(lines) do
      -- Look for diff header patterns
      if line:match '^---%s+' or line:match '^%+%+%+%s+' then
        if not in_diff then
          in_diff = true
          found_diff_header = true
          diff_lines = { line }
        else
          table.insert(diff_lines, line)
        end
      elseif in_diff then
        -- Continue collecting diff lines
        if line:match '^@@' or line:match '^[-+]' or line:match '^%s' then
          table.insert(diff_lines, line)
        elseif line:match '^$' then
          -- Empty lines are okay in diffs
          table.insert(diff_lines, line)
        else
          -- Non-diff line found, check if we have a complete diff
          if found_diff_header and #diff_lines > 2 then
            break
          else
            -- Reset if we don't have a valid diff yet
            in_diff = false
            found_diff_header = false
            diff_lines = {}
          end
        end
      end
    end

    if found_diff_header and #diff_lines > 2 then
      return table.concat(diff_lines, '\n')
    end

    return nil
  end

  --- Applies a single parsed diff to the corresponding file.
  -- @param parsed_diff The diff table from parse_diff.
  -- @return boolean, string: success status and a message.
  function VibePatcher.apply_diff(parsed_diff)
    local target_file = parsed_diff.new_path
    if target_file == '/dev/null' then
      return true, 'Skipped file deletion.'
    end

    local original_lines
    local is_new_file = parsed_diff.old_path == '/dev/null'

    if is_new_file then
      original_lines = {}
    else
      local content, err = FileCache.get_content(parsed_diff.old_path)
      if not content then
        return false, 'Failed to read file ' .. parsed_diff.old_path .. ': ' .. (err or 'Unknown Error')
      end
      original_lines = vim.split(content, '\n', { plain = true })
    end

    local modified_lines = vim.deepcopy(original_lines)
    local hunks_applied_count = 0

    for _, hunk in ipairs(parsed_diff.hunks) do
      local to_remove = {}
      local to_add = {}
      for _, line in ipairs(hunk.lines) do
        local op = line:sub(1, 1)
        local text = line:sub(2)
        if op == '-' then
          table.insert(to_remove, text)
        elseif op == '+' then
          table.insert(to_add, text)
        end
      end

      local found_at = -1
      if #to_remove > 0 then
        for i = 1, #modified_lines - #to_remove + 1 do
          local match = true
          for j = 1, #to_remove do
            if modified_lines[i + j - 1] ~= to_remove[j] then
              match = false
              break
            end
          end
          if match then
            found_at = i
            break
          end
        end
      elseif is_new_file or #to_add > 0 then
        found_at = #modified_lines + 1
      end

      if found_at > -1 then
        local prefix = {}
        for i = 1, found_at - 1 do
          table.insert(prefix, modified_lines[i])
        end

        local suffix = {}
        local start_of_suffix = found_at + #to_remove
        for i = start_of_suffix, #modified_lines do
          table.insert(suffix, modified_lines[i])
        end

        modified_lines = prefix
        for _, line in ipairs(to_add) do
          table.insert(modified_lines, line)
        end
        for _, line in ipairs(suffix) do
          table.insert(modified_lines, line)
        end

        hunks_applied_count = hunks_applied_count + 1
      else
        return false, 'Failed to apply a hunk to ' .. target_file .. '. Aborting.'
      end
    end

    if hunks_applied_count == #parsed_diff.hunks then
      local success, write_err = Utils.write_file(target_file, modified_lines)
      if not success then
        return false, 'Failed to write changes to ' .. target_file .. ': ' .. (write_err or '')
      end
      return true, 'Applied ' .. hunks_applied_count .. ' hunks to ' .. target_file
    else
      return false, 'Not all hunks could be applied to ' .. target_file
    end
  end

  --- Finds the last AI response, extracts diffs, and applies them.
  function VibePatcher.apply_last_response()
    local messages = VibeChat.get_messages()
    local last_ai_message = nil
    for i = #messages, 1, -1 do
      if messages[i].role == 'assistant' then
        last_ai_message = messages[i].content
        break
      end
    end

    if not last_ai_message then
      vim.notify('[Vibe] No AI response found to apply.', vim.log.levels.WARN)
      return
    end

    local code_blocks = VibeDiff.extract_code_blocks(last_ai_message)
    local diff_blocks = {}

    -- First, look for explicit diff code blocks
    for _, block in ipairs(code_blocks) do
      if block.language == 'diff' then
        table.insert(diff_blocks, block.content_str)
      end
    end

    -- If no explicit diff blocks found, look for diff patterns in the raw message
    if #diff_blocks == 0 then
      local diff_content = VibePatcher.extract_diff_from_text(last_ai_message)
      if diff_content then
        table.insert(diff_blocks, diff_content)
      end
    end

    if #diff_blocks == 0 then
      vim.notify('[Vibe] No diff blocks found in the last AI response.', vim.log.levels.WARN)
      return
    end

    local applied_count = 0
    local failed_count = 0
    for _, diff_content in ipairs(diff_blocks) do
      local parsed_diff, parse_err = VibePatcher.parse_diff(diff_content)
      if parsed_diff then
        local success, apply_msg = VibePatcher.apply_diff(parsed_diff)
        if success then
          vim.notify('[Vibe] ' .. apply_msg, vim.log.levels.INFO)
          applied_count = applied_count + 1
        else
          vim.notify('[Vibe] ' .. apply_msg, vim.log.levels.ERROR)
          failed_count = failed_count + 1
        end
      else
        vim.notify('[Vibe] Failed to parse diff: ' .. (parse_err or ''), vim.log.levels.ERROR)
        failed_count = failed_count + 1
      end
    end

    vim.notify(
      '[Vibe] Patch complete. Applied: ' .. applied_count .. '. Failed: ' .. failed_count .. '.',
      vim.log.levels.INFO
    )
  end
end

-- =============================================================================
-- User Commands
-- =============================================================================
vim.api.nvim_create_user_command(
  'VibeChat',
  VibeChat.open_chat_window,
  { desc = 'Open the Vibe Coding sidebar layout' }
)
vim.api.nvim_create_user_command('VibeClose', VibeChat.close_layout, { desc = 'Close the Vibe Coding sidebar' })
vim.api.nvim_create_user_command('VibeToggle', function()
  if VibeChat.state.layout_active then
    VibeChat.close_layout()
  else
    VibeChat.open_chat_window()
  end
end, { desc = 'Toggle the Vibe Coding sidebar layout' })
vim.api.nvim_create_user_command(
  'VibeAddToContext',
  VibeChat.add_context_to_chat,
  { desc = 'Add a file to the Vibe chat context using fd' }
)
vim.api.nvim_create_user_command(
  'VibeAddCurrentBuffer',
  VibeChat.add_current_buffer_to_context,
  { desc = 'Add the current buffer to the Vibe chat context' }
)
vim.api.nvim_create_user_command(
  'VibeDiff',
  VibeDiff.show,
  { desc = 'Diff the last AI code block with the main editor buffer' }
)

vim.api.nvim_create_user_command(
  'VibeApplyPatch',
  VibePatcher.apply_last_response,
  { desc = 'Apply diff from the last AI response to the corresponding file(s)' }
)

vim.api.nvim_create_user_command('VibeSessionStart', function(opts)
  -- If chat is not open, open it
  if not VibeChat.state.layout_active then
    VibeChat.open_chat_window()
  end

  local session_name = opts.args ~= '' and opts.args or nil
  VibeChat.sessions.start(session_name)
end, {
  nargs = '?',
  desc = 'Start a new Vibe session with optional name',
})

vim.api.nvim_create_user_command('VibeSessionEnd', function()
  VibeChat.sessions.end_session()
end, {
  desc = 'Save and end the current Vibe session',
})

vim.api.nvim_create_user_command('VibeSessionLoad', function()
  VibeChat.sessions.load_interactive()
end, {
  desc = 'Load a saved Vibe session',
})

vim.api.nvim_create_user_command('VibeSessionList', function()
  local sessions = VibeChat.sessions.list()
  if #sessions > 0 then
    print 'Available sessions:'
    for _, session in ipairs(sessions) do
      print('- ' .. session)
    end
  end
end, {
  desc = 'List all saved Vibe sessions',
})

vim.api.nvim_create_user_command('VibeSessionDelete', function()
  VibeChat.sessions.delete_interactive()
end, {
  desc = 'Delete a saved Vibe session',
})

vim.api.nvim_create_user_command('VibeSessionRename', function()
  VibeChat.sessions.rename_interactive()
end, {
  desc = 'Rename the current Vibe session',
})

vim.api.nvim_create_user_command(
  'VibeRemoveFromContext',
  VibeChat.remove_context_from_chat,
  { desc = 'Remove a file from the Vibe chat context' }
)

vim.api.nvim_create_user_command(
  'VibeClearContext',
  VibeChat.clear_context,
  { desc = 'Clear all files from the Vibe chat context' }
)

vim.api.nvim_create_user_command('VibeDebugOn', function()
  CONFIG.debug_mode = true
  vim.notify('[Vibe] Debug mode enabled. API calls will generate debug scripts.', vim.log.levels.INFO)
end, {
  desc = 'Enable Vibe debug mode - generates curl scripts for API calls',
})

vim.api.nvim_create_user_command('VibeDebugOff', function()
  CONFIG.debug_mode = false
  vim.notify('[Vibe] Debug mode disabled.', vim.log.levels.INFO)
end, {
  desc = 'Disable Vibe debug mode',
})

vim.api.nvim_create_user_command('VibeDebugStatus', function()
  local status = CONFIG.debug_mode and 'enabled' or 'disabled'
  local debug_dir = vim.fn.stdpath 'data' .. '/vibe-debug'
  vim.notify('[Vibe] Debug mode is ' .. status .. '. Debug files stored in: ' .. debug_dir, vim.log.levels.INFO)
end, {
  desc = 'Show current Vibe debug mode status',
})

vim.api.nvim_create_user_command('VibeDebugToggle', function()
  CONFIG.debug_mode = not CONFIG.debug_mode
  local status = CONFIG.debug_mode and 'enabled' or 'disabled'
  vim.notify('[Vibe] Debug mode ' .. status .. '.', vim.log.levels.INFO)

  -- Create debug directory if enabling and it doesn't exist
  if CONFIG.debug_mode then
    local debug_dir = vim.fn.stdpath 'data' .. '/vibe-debug'
    if vim.fn.isdirectory(debug_dir) == 0 then
      vim.fn.mkdir(debug_dir, 'p')
      vim.notify('[Vibe] Created debug directory: ' .. debug_dir, vim.log.levels.INFO)
    end
  end
end, {
  desc = 'Toggle Vibe debug mode on/off',
})

-- Auto-save session on Neovim exit to prevent history loss
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    if VibeChat.sessions.current_session_id then
      VibeChat.sessions.save()
    end
  end,
  desc = 'Auto-save vibe session on Neovim exit',
})

-- Export the VibeDiff module
return {
  VibeDiff = VibeDiff,
}
