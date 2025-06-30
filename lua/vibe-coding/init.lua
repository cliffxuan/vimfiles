-- vibe-coding.lua
-- A single-file OpenAI coding assistant for Neovim

-- =============================================================================
-- Vibe API: Handles communication with the OpenAI API
-- =============================================================================
local VibeAPI = {}

do
  local plenary_job = require 'plenary.job'
  local api_key = os.getenv 'OPENAI_API_KEY'
  local api_url = 'https://api.openai.com/v1/chat/completions'

  function VibeAPI.get_completion(messages, callback)
    if not api_key or api_key == '' then
      vim.notify('[Vibe] OPENAI_API_KEY environment variable not set.', vim.log.levels.ERROR)
      callback(nil, 'API Key not set.')
      return
    end

    local data = {
      model = 'gpt-4o',
      messages = messages,
    }

    plenary_job
      :new({
        command = 'curl',
        args = {
          '-s',
          '-X',
          'POST',
          api_url,
          '-H',
          'Content-Type: application/json',
          '-H',
          'Authorization: Bearer ' .. api_key,
          '-d',
          vim.fn.json_encode(data),
        },
        on_exit = vim.schedule_wrap(function(job, return_val)
          if return_val == 0 then
            local response = vim.fn.json_decode(job:result())
            if response and response.choices and #response.choices > 0 then
              callback(response.choices[1].message.content)
            elseif response and response.error then
              vim.notify('[Vibe] OpenAI API Error: ' .. response.error.message, vim.log.levels.ERROR)
              callback(nil, 'API Error: ' .. response.error.message)
            else
              vim.notify('[Vibe] No completion received from OpenAI.', vim.log.levels.WARN)
              callback(nil, 'No completion received.')
            end
          else
            vim.notify('[Vibe] Error calling OpenAI API. Check curl command.', vim.log.levels.ERROR)
            callback(nil, 'HTTP request failed.')
          end
        end),
      })
      :start()
  end
end

-- =============================================================================
-- Vibe Context: Manages adding file context using fd
-- =============================================================================
local VibeContext = {}
do
  function VibeContext.add_file_to_context(callback)
    vim.ui.input({ prompt = 'fd query: ' }, function(query)
      if not query then
        return
      end

      require('plenary.job')
        :new({
          command = 'fd',
          args = { '--absolute-path', query },
          on_exit = vim.schedule_wrap(function(j, return_val)
            if return_val == 0 then
              local files = j:result()
              if #files == 0 then
                vim.notify('[Vibe] No files found for query: ' .. query, vim.log.levels.WARN)
                return
              end
              vim.ui.select(files, { prompt = 'Select a file to add to context:' }, function(choice)
                if not choice then
                  return
                end
                callback(choice)
              end)
            else
              vim.notify('[Vibe] Error running fd. Is it installed?', vim.log.levels.ERROR)
            end
          end),
        })
        :start()
    end)
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

  -- Accessor function to safely get messages from other modules
  function VibeChat.get_messages()
    return messages_for_display
  end

  function VibeChat.update_context_buffer()
    local buf_id = VibeChat.state.context_buf_id
    if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
      return
    end

    local display_lines = { '--- Context Files ---' }
    for _, file_path in ipairs(VibeChat.state.context_files) do
      table.insert(display_lines, vim.fn.fnamemodify(file_path, ':t')) -- Show only filename
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

    VibeChat.state.main_editor_win_id = vim.api.nvim_get_current_win()

    -- 1. Create sidebar and get its total available height
    vim.cmd 'vsplit'
    vim.cmd 'vertical resize 80'
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
    local input_height = math.max(3, math.floor(sidebar_height * 0.1))
    local context_height = math.max(2, math.floor(sidebar_height * 0.1))
    local output_height = sidebar_height - input_height - context_height

    vim.api.nvim_win_set_height(VibeChat.state.output_win_id, output_height)
    vim.api.nvim_win_set_height(VibeChat.state.context_win_id, context_height)
    vim.api.nvim_win_set_height(VibeChat.state.input_win_id, input_height)

    -- 5. Create and configure buffers
    VibeChat.state.output_buf_id = vim.api.nvim_create_buf(false, true)
    VibeChat.state.context_buf_id = vim.api.nvim_create_buf(false, true)
    VibeChat.state.input_buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(VibeChat.state.output_win_id, VibeChat.state.output_buf_id)
    vim.api.nvim_win_set_buf(VibeChat.state.context_win_id, VibeChat.state.context_buf_id)
    vim.api.nvim_win_set_buf(VibeChat.state.input_win_id, VibeChat.state.input_buf_id)

    vim.bo[VibeChat.state.output_buf_id].filetype, vim.bo[VibeChat.state.output_buf_id].modifiable, vim.bo[VibeChat.state.output_buf_id].buflisted =
      'markdown', false, false
    vim.bo[VibeChat.state.context_buf_id].modifiable, vim.bo[VibeChat.state.context_buf_id].buflisted = false, false
    vim.bo[VibeChat.state.input_buf_id].buflisted = false
    vim.api.nvim_buf_set_name(VibeChat.state.output_buf_id, 'vibe-output')
    vim.api.nvim_buf_set_name(VibeChat.state.context_buf_id, 'vibe-context')
    vim.api.nvim_buf_set_name(VibeChat.state.input_buf_id, 'vibe-input')

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

    -- 7. Initialize chat and state
    messages_for_display = {}
    VibeChat.append_to_output 'Welcome to Vibe Coding! Submit with Ctrl+s (Insert) or Enter (Normal).'

    local initial_buf_name = ''
    if VibeChat.state.main_editor_win_id and vim.api.nvim_win_is_valid(VibeChat.state.main_editor_win_id) then
      local buf_id = vim.api.nvim_win_get_buf(VibeChat.state.main_editor_win_id)
      initial_buf_name = vim.api.nvim_buf_get_name(buf_id)
    end

    if initial_buf_name and initial_buf_name ~= '' then
      VibeChat.state.context_files = { initial_buf_name }
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
    local to_close = { VibeChat.state.output_win_id, VibeChat.state.context_win_id, VibeChat.state.input_win_id }
    VibeChat.state.layout_active = false
    VibeChat.state.context_files = {}
    vim.api.nvim_clear_autocmds { group = VIBE_AUGROUP }
    for _, win_id in ipairs(to_close) do
      if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
      end
    end
  end

  function VibeChat.append_to_output(text)
    local buf_id = VibeChat.state.output_buf_id
    if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
      return
    end
    vim.bo[buf_id].modifiable = true
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, vim.split(text, '\n', { trimempty = true }))
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, { '' })
    vim.bo[buf_id].modifiable = false
    local win_id = VibeChat.state.output_win_id
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_set_cursor(win_id, { vim.api.nvim_buf_line_count(buf_id), 0 })
    end
  end

  function VibeChat.send_message()
    if VibeChat.state.is_thinking then
      return
    end
    local input_buf = VibeChat.state.input_buf_id
    local user_input = table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), '\n')
    if user_input == '' then
      return
    end

    vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {})
    VibeChat.append_to_output('👤 You:\n' .. user_input)
    table.insert(messages_for_display, { role = 'user', content = user_input })

    VibeChat.state.is_thinking = true
    VibeChat.append_to_output '🤔 AI is thinking...'

    local messages_for_api = {
      {
        role = 'system',
        content = "You are a helpful coding assistant. Use the provided file contexts to answer the user's prompt.",
      },
    }
    for _, file_path in ipairs(VibeChat.state.context_files) do
      local content = table.concat(vim.fn.readfile(file_path), '\n')
      local context_msg = 'CONTEXT from file `'
        .. vim.fn.fnamemodify(file_path, ':p')
        .. '`:\n\n```\n'
        .. content
        .. '\n```'
      table.insert(messages_for_api, { role = 'user', content = context_msg })
    end
    table.insert(messages_for_api, { role = 'user', content = user_input })

    VibeAPI.get_completion(messages_for_api, function(response_text, err)
      if not VibeChat.state.layout_active then
        return
      end

      local output_lines = vim.api.nvim_buf_get_lines(VibeChat.state.output_buf_id, 0, -1, false)
      for i = #output_lines, 1, -1 do
        if string.find(output_lines[i], '🤔 AI is thinking...') then
          vim.bo[VibeChat.state.output_buf_id].modifiable = true
          vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, i - 1, i, false, {})
          vim.bo[VibeChat.state.output_buf_id].modifiable = false
          break
        end
      end

      if err then
        VibeChat.append_to_output('Error: ' .. err)
      else
        table.insert(messages_for_display, { role = 'assistant', content = response_text })
        VibeChat.append_to_output('🤖 AI:\n' .. response_text)
      end
      VibeChat.state.is_thinking = false
    end)
  end

  function VibeChat.add_context_to_chat()
    if not VibeChat.state.layout_active then
      vim.notify('[Vibe] Chat layout is not open.', vim.log.levels.WARN)
      return
    end
    VibeContext.add_file_to_context(function(filepath)
      if filepath then
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
    end)
  end

  function VibeChat.add_current_buffer_to_context()
    if not VibeChat.state.layout_active then
      vim.notify('[Vibe] Chat layout is not open.', vim.log.levels.WARN)
      return
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
end

-- =============================================================================
-- Vibe Diff: Shows diff between AI response and main editor window
-- =============================================================================
local VibeDiff = {}
do
  function VibeDiff.get_last_ai_response()
    local messages = VibeChat.get_messages() -- Use the accessor
    local last_ai_message = nil
    for i = #messages, 1, -1 do
      if messages[i].role == 'assistant' then
        last_ai_message = messages[i].content
        break
      end
    end
    if not last_ai_message then
      return nil
    end

    local code_blocks = {}
    local in_code_block = false
    local current_block = {}
    for _, line in ipairs(vim.split(last_ai_message, '\n')) do
      if string.match(line, '^```') then
        if in_code_block then
          in_code_block = false
          table.insert(code_blocks, table.concat(current_block, '\n'))
          current_block = {}
        else
          in_code_block = true
        end
      elseif in_code_block then
        table.insert(current_block, line)
      end
    end
    return #code_blocks > 0 and code_blocks[#code_blocks] or nil
  end

  function VibeDiff.show()
    local ai_content = VibeDiff.get_last_ai_response()
    if not ai_content then
      vim.notify('[Vibe] No code block found in the last AI response.', vim.log.levels.WARN)
      return
    end
    local main_win = VibeChat.state.main_editor_win_id
    if not main_win or not vim.api.nvim_win_is_valid(main_win) then
      vim.notify('[Vibe] Main editor window is no longer valid.', vim.log.levels.ERROR)
      return
    end
    vim.api.nvim_set_current_win(main_win)
    local diff_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(diff_buf, 0, -1, false, vim.split(ai_content, '\n'))
    vim.cmd 'diffthis'
    vim.cmd 'vsplit'
    vim.api.nvim_set_current_buf(diff_buf)
    vim.bo[diff_buf].buftype, vim.bo[diff_buf].swapfile = 'nofile', false
    vim.cmd 'diffthis'
    vim.notify 'Use :diffget/:diffput or `do`/`dp` to merge.'
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

print 'Vibe Coding plugin loaded! Use :VibeChat to open the sidebar.'
