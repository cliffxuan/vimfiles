-- VibeChat: Main chat interface and UI management
local Utils = require 'vibe-coding.utils'
local PromptManager = require 'vibe-coding.prompt_manager'
local SessionManager = require 'vibe-coding.session_manager'
local VibePatcher = require 'vibe-coding.patcher'

local VibeChat = {}

-- State management
local messages_for_display = {}
local VIBE_AUGROUP = vim.api.nvim_create_augroup('Vibe', { clear = true })
local CONFIG = nil -- Will be set by configure function

-- Configuration function
function VibeChat.configure(config)
  CONFIG = config or {}
end

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
  vim.cmd('vertical resize ' .. (CONFIG and CONFIG.sidebar_width or 80))
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
  local input_height = math.max(
    (CONFIG and CONFIG.min_input_height or 3),
    math.floor(sidebar_height * (CONFIG and CONFIG.input_height_ratio or 0.1))
  )
  local context_height = math.max(
    (CONFIG and CONFIG.min_context_height or 2),
    math.floor(sidebar_height * (CONFIG and CONFIG.context_height_ratio or 0.1))
  )
  local output_height = sidebar_height - input_height - context_height

  vim.api.nvim_win_set_height(VibeChat.state.output_win_id, output_height)
  vim.api.nvim_win_set_height(VibeChat.state.context_win_id, context_height)
  vim.api.nvim_win_set_height(VibeChat.state.input_win_id, input_height)

  -- 4.1 Set window options to prevent automatic resizing
  local sidebar_width = CONFIG and CONFIG.sidebar_width or 80
  vim.api.nvim_win_set_width(VibeChat.state.output_win_id, sidebar_width)
  vim.api.nvim_win_set_width(VibeChat.state.context_win_id, sidebar_width)
  vim.api.nvim_win_set_width(VibeChat.state.input_win_id, sidebar_width)

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
  -- Do not fold lines by default in output window
  vim.wo[VibeChat.state.output_win_id].foldenable = false

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
  SessionManager.init()

  -- Add welcome message to output buffer
  vim.api.nvim_buf_set_lines(
    VibeChat.state.output_buf_id,
    0,
    -1,
    false,
    vim.split(
      'Welcome to Vibe Coding!\nAPI URL: '
        .. (CONFIG and CONFIG.api_url or 'Not configured')
        .. '\nModel: '
        .. (CONFIG and CONFIG.model or 'Not configured')
        .. '\nSubmit with Ctrl+s (Insert) or Enter (Normal).',
      '\n'
    )
  )

  -- Load session or create new one
  local session_to_load

  if SessionManager.current_session_id then
    session_to_load = SessionManager.current_session_id
  else
    session_to_load = SessionManager.get_most_recent()
    if not session_to_load then
      session_to_load = os.date '%Y%m%d_%H%M%S'
    end
  end

  -- Now actually load the session (this will populate messages and context)
  if session_to_load then
    local _, loaded_messages =
      SessionManager.start(session_to_load, VibeChat.state, VibeChat.update_context_buffer, VibeChat.append_to_output)
    if loaded_messages then
      messages_for_display = loaded_messages
    end
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
      SessionManager.save(messages_for_display, VibeChat.state) -- Save the updated context
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
  if SessionManager.current_session_id then
    SessionManager.save(messages_for_display, VibeChat.state)
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

  -- Check if we're about to close the last window(s)
  local total_wins = vim.fn.winnr '$'
  local vibe_wins = 0
  for _, win_id in ipairs(to_close) do
    if win_id and vim.api.nvim_win_is_valid(win_id) then
      vibe_wins = vibe_wins + 1
    end
  end

  -- If vibe windows are the only windows, create a new buffer first
  if total_wins == vibe_wins then
    vim.cmd 'new'
  end

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

-- Session management functions
function VibeChat.load_session_interactive()
  local sessions_with_data = SessionManager.load_sessions_with_data()
  if not sessions_with_data then
    vim.notify('[Vibe] No saved sessions found.', vim.log.levels.INFO)
    return
  end

  Utils.create_telescope_picker {
    prompt_title = 'Select Session to Load',
    items = sessions_with_data,
    disable_multi_selection = true,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry.display,
        ordinal = entry.name,
      }
    end,
    previewer = require('telescope.previewers').new_buffer_previewer {
      title = 'Session Preview',
      define_preview = function(self, entry)
        local lines = SessionManager.create_session_preview(entry.value)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    },
    on_selection = function(selection)
      if not VibeChat.state.layout_active then
        VibeChat.open_chat_window()
      end
      local _, loaded_messages =
        SessionManager.start(selection.name, VibeChat.state, VibeChat.update_context_buffer, VibeChat.append_to_output)
      if loaded_messages then
        messages_for_display = loaded_messages
      end
    end,
  }
end

function VibeChat.delete_session_interactive()
  local sessions_with_data = SessionManager.load_sessions_with_data()
  if not sessions_with_data then
    vim.notify('[Vibe] No saved sessions found.', vim.log.levels.INFO)
    return
  end

  Utils.create_telescope_picker {
    prompt_title = 'Select Session to Delete',
    items = sessions_with_data,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry.display,
        ordinal = entry.name,
      }
    end,
    previewer = require('telescope.previewers').new_buffer_previewer {
      title = 'Session Preview',
      define_preview = function(self, entry)
        local lines = SessionManager.create_session_preview(entry.value)
        table.insert(lines, 1, '🗑️  DELETE MODE - Review session before deletion')
        table.insert(lines, 2, '')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      end,
    },
    on_selection = function(selection)
      -- Handle single selection
      vim.ui.input({
        prompt = "Are you sure you want to delete session '" .. selection.name .. "'? (y/N): ",
      }, function(input)
        if input and input:lower() == 'y' then
          vim.fn.delete(selection.file)
          vim.notify('[Vibe] Deleted session: ' .. selection.name, vim.log.levels.INFO)

          -- If we deleted the current session, clear the session ID
          if SessionManager.current_session_id == selection.name then
            SessionManager.current_session_id = nil
          end
        end
      end)
    end,
    on_multi_selection = function(selections)
      -- Handle multiple selections
      local session_names = {}
      for _, session in ipairs(selections) do
        table.insert(session_names, session.name)
      end

      local prompt_text = 'Are you sure you want to delete '
        .. #selections
        .. ' sessions?\n'
        .. 'Sessions: '
        .. table.concat(session_names, ', ')
        .. '\n(y/N): '

      vim.ui.input({
        prompt = prompt_text,
      }, function(input)
        if input and input:lower() == 'y' then
          local deleted_count = 0
          local current_cleared = false

          for _, session in ipairs(selections) do
            if vim.fn.delete(session.file) == 0 then
              deleted_count = deleted_count + 1

              -- If we deleted the current session, clear the session ID
              if SessionManager.current_session_id == session.name then
                SessionManager.current_session_id = nil
                current_cleared = true
              end
            else
              vim.notify('[Vibe] Failed to delete session: ' .. session.name, vim.log.levels.ERROR)
            end
          end

          if deleted_count > 0 then
            local msg = '[Vibe] Deleted ' .. deleted_count .. ' session(s)'
            if current_cleared then
              msg = msg .. ' (current session cleared)'
            end
            vim.notify(msg, vim.log.levels.INFO)
          end
        end
      end)
    end,
  }
end

-- Message sending function
function VibeChat.send_message()
  require('vibe-coding.chat_handlers').send_message(VibeChat.state, CONFIG)
end

-- Context management functions
function VibeChat.add_context_to_chat()
  require('vibe-coding.context_manager').add_context_to_chat(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.add_buffer_context_to_chat()
  require('vibe-coding.context_manager').add_buffer_context_to_chat(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.remove_context_from_chat()
  require('vibe-coding.context_manager').remove_context_from_chat(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.add_current_buffer_to_context()
  require('vibe-coding.context_manager').add_current_buffer_to_context(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.clear_context()
  require('vibe-coding.context_manager').clear_context(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.remove_single_file_from_context()
  require('vibe-coding.context_manager').remove_single_file_from_context(VibeChat.state, VibeChat.open_chat_window)
end

function VibeChat.remove_selected_files_from_context()
  require('vibe-coding.context_manager').remove_selected_files_from_context(VibeChat.state, VibeChat.open_chat_window)
end

-- Prompt management
function VibeChat.select_prompt()
  if not VibeChat.state.layout_active then
    VibeChat.open_chat_window()
  end

  local old_prompt = PromptManager.selected_prompt_name
  PromptManager.select_prompt(function(new_prompt_name)
    if old_prompt ~= new_prompt_name then
      VibeChat.append_to_output('Prompt updated to "' .. new_prompt_name .. '"')

      -- If chat output buffer exists, update the header
      if VibeChat.state.output_buf_id and vim.api.nvim_buf_is_valid(VibeChat.state.output_buf_id) then
        vim.bo[VibeChat.state.output_buf_id].modifiable = true
        local lines = vim.api.nvim_buf_get_lines(VibeChat.state.output_buf_id, 0, -1, false)

        -- Find and update API URL, model and prompt lines
        for i, line in ipairs(lines) do
          if line:match '^API URL:' then
            lines[i] = 'API URL: ' .. (CONFIG and CONFIG.api_url or 'Not configured')
          elseif line:match '^Model:' then
            lines[i] = 'Model: ' .. (CONFIG and CONFIG.model or 'Not configured')
          elseif line:match '^Prompt:' then
            lines[i] = 'Prompt: ' .. new_prompt_name
          end
        end
        vim.api.nvim_buf_set_lines(VibeChat.state.output_buf_id, 0, -1, false, lines)
        vim.bo[VibeChat.state.output_buf_id].modifiable = false
      end
    end
  end)
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

  vim.notify('[Vibe] Code block diff opened. Use q to close, <leader>da to accept suggestion', vim.log.levels.INFO)
end

function VibeChat.get_relevant_code_block()
  local last_ai_message = nil

  for i = #messages_for_display, 1, -1 do
    if messages_for_display[i].role == 'assistant' then
      last_ai_message = messages_for_display[i].content
      break
    end
  end

  if not last_ai_message then
    return nil, 'No AI response found'
  end

  local code_blocks = VibePatcher.extract_code_blocks(last_ai_message)
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

return VibeChat
