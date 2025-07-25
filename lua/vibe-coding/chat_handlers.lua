-- Chat handlers: Message sending, streaming, and interaction logic
local Utils = require 'vibe-coding.utils'
local VibeAPI = require 'vibe-coding.api'
local PromptManager = require 'vibe-coding.prompt_manager'
local SessionManager = require 'vibe-coding.session_manager'

local ChatHandlers = {}

-- Helper function to get user input
local function get_user_input(state)
  local input_buf = state.input_buf_id
  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
    vim.notify('[Vibe] Input buffer is not valid.', vim.log.levels.ERROR)
    return nil
  end

  local user_input = table.concat(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), '\n')
  if user_input == '' or user_input:match '^%s*$' then
    vim.notify('[Vibe] Please enter a message.', vim.log.levels.WARN)
    return nil
  end

  return user_input
end

-- Helper function to build API payload
local function build_api_payload(user_input, state)
  local prompt_content = PromptManager.get_prompt_content()
  local messages_for_api = {
    { role = 'system', content = prompt_content },
  }

  -- Add file context
  for _, file_path in ipairs(state.context_files) do
    local content, err = Utils.read_file_content(file_path)
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

  -- Add conversation history (excluding the current user input)
  local messages_for_display = require('vibe-coding.chat').get_messages()
  for _, msg in ipairs(messages_for_display) do
    if msg.role == 'user' or msg.role == 'assistant' then
      table.insert(messages_for_api, { role = msg.role, content = msg.content })
    end
  end

  -- Add current user input
  table.insert(messages_for_api, { role = 'user', content = user_input })
  return messages_for_api
end

-- Helper function to handle timeout
local function handle_timeout(state, config)
  if not state.is_thinking then
    return
  end
  state.is_thinking = false

  if state.layout_active then
    local output_lines = vim.api.nvim_buf_get_lines(state.output_buf_id, 0, -1, false)
    for i = #output_lines, 1, -1 do
      if string.find(output_lines[i], '🤔 AI is thinking...') then
        vim.bo[state.output_buf_id].modifiable = true
        vim.api.nvim_buf_set_lines(state.output_buf_id, i - 1, i, false, {})
        vim.bo[state.output_buf_id].modifiable = false
        break
      end
    end
    local timeout_secs = config.request_timeout_ms / 1000
    require('vibe-coding.chat').append_to_output('❌ Request timed out after ' .. timeout_secs .. ' seconds')
  end
end

-- Helper function to handle streaming chunks
local function handle_stream_chunk(chunk, streaming_started, state)
  if not state.layout_active or not state.is_thinking then
    return streaming_started
  end

  local output_buf = state.output_buf_id
  if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then
    return streaming_started
  end

  if not streaming_started then
    vim.bo[output_buf].modifiable = true
    local lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
    for i = #lines, 1, -1 do
      if string.find(lines[i], '🤔 AI is thinking...') then
        vim.api.nvim_buf_set_lines(output_buf, i - 1, i, false, { '🤖 AI:' })
        break
      end
    end
    vim.bo[output_buf].modifiable = false
    streaming_started = true
  end

  vim.bo[output_buf].modifiable = true
  local chunk_lines = vim.split(chunk, '\n', { plain = true })
  local buffer_lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
  local last_line_index = #buffer_lines

  if last_line_index > 0 then
    buffer_lines[last_line_index] = buffer_lines[last_line_index] .. chunk_lines[1]
    if #chunk_lines > 1 then
      for i = 2, #chunk_lines do
        table.insert(buffer_lines, chunk_lines[i])
      end
    end
    vim.api.nvim_buf_set_lines(output_buf, last_line_index - 1, -1, false, { unpack(buffer_lines, last_line_index) })
  end
  vim.bo[output_buf].modifiable = false

  local win_id = vim.fn.bufwinid(output_buf)
  if win_id ~= -1 then
    local final_line_count = vim.api.nvim_buf_line_count(output_buf)
    vim.api.nvim_win_set_cursor(win_id, { final_line_count, 0 })
  end

  return streaming_started
end

-- Helper function to handle completion
local function handle_completion(response_text, err, timeout_timer, state)
  vim.fn.timer_stop(timeout_timer)
  state.is_thinking = false

  if not state.layout_active then
    return
  end

  local messages_for_display = require('vibe-coding.chat').get_messages()

  if err then
    local output_lines = vim.api.nvim_buf_get_lines(state.output_buf_id, 0, -1, false)
    for i = #output_lines, 1, -1 do
      if string.find(output_lines[i], '🤔 AI is thinking...') then
        vim.bo[state.output_buf_id].modifiable = true
        vim.api.nvim_buf_set_lines(state.output_buf_id, i - 1, i, false, {})
        vim.bo[state.output_buf_id].modifiable = false
        break
      end
    end
    require('vibe-coding.chat').append_to_output('❌ Error: ' .. err)
  else
    table.insert(messages_for_display, { role = 'assistant', content = response_text })
  end

  if SessionManager.current_session_id then
    SessionManager.save(messages_for_display, state)
  end
end

-- Main message sending function
function ChatHandlers.send_message(state, config)
  if state.is_thinking then
    vim.notify('[Vibe] Please wait for the AI to finish responding.', vim.log.levels.WARN)
    return
  end

  local user_input = get_user_input(state)
  if not user_input then
    return
  end

  state.is_thinking = true
  vim.api.nvim_buf_set_lines(state.input_buf_id, 0, -1, false, {})
  local append_to_output = require('vibe-coding.chat').append_to_output
  append_to_output('👤 You:\n' .. user_input)

  local messages_for_display = require('vibe-coding.chat').get_messages()
  table.insert(messages_for_display, { role = 'user', content = user_input })
  append_to_output '🤔 AI is thinking...'

  local messages_for_api = build_api_payload(user_input, state)
  local timeout_timer = vim.fn.timer_start(config.request_timeout_ms, function()
    handle_timeout(state, config)
  end)
  local streaming_started = false

  VibeAPI.get_completion(messages_for_api, function(response_text, err)
    handle_completion(response_text, err, timeout_timer, state)
  end, function(chunk)
    streaming_started = handle_stream_chunk(chunk, streaming_started, state)
  end, config)
end

return ChatHandlers
