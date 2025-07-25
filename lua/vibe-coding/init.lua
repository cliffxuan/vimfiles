-- vibe-coding.lua - Main entry point with modular architecture
local Utils = require 'vibe-coding.utils'
local VibeDiff = require 'vibe-coding.diff'
local VibePatcher = require 'vibe-coding.patcher'
local Validation = require 'vibe-coding.validation'
local VibeChat = require 'vibe-coding.chat'
local SessionManager = require 'vibe-coding.session_manager'

-- =============================================================================
-- Configuration Constants
-- =============================================================================
local CONFIG = {
  -- API Configuration (placeholders, will be overridden)
  api_key = nil,
  api_url = nil,
  model = nil,

  -- UI Configuration
  sidebar_width = 80,
  input_height_ratio = 0.1,
  context_height_ratio = 0.1,
  min_input_height = 3,
  min_context_height = 2,

  -- Timeout for API requests in milliseconds (default 5 minutes)
  request_timeout_ms = 300000,
  -- Debug Settings
  debug_mode = false,
}

-- Function to load external config file (expects Lua file returning a table with keys)
local function load_external_config()
  local config_path = vim.fn.expand '$HOME/.config/vibe-coding/config.lua'
  if vim.fn.filereadable(config_path) ~= 1 then
    return nil
  end
  local ok, conf = pcall(dofile, config_path)
  if ok and type(conf) == 'table' then
    return conf
  end
  return nil
end

-- Load configuration
do
  local ext_conf = load_external_config() or {}

  CONFIG.api_key = ext_conf.API_KEY or os.getenv 'OPENAI_API_KEY' or nil
  CONFIG.api_url = ext_conf.API_URL or os.getenv 'OPENAI_BASE_URL' or 'https://api.openai.com/v1'
  CONFIG.model = ext_conf.MODEL or os.getenv 'OPENAI_CHAT_MODEL_ID' or 'gpt-4.1-mini'
end

-- =============================================================================
-- Add session management functions directly to VibeChat
-- =============================================================================

-- Session management functions
function VibeChat.sessions_start(session_name)
  local loaded_session, _ =
    SessionManager.start(session_name, VibeChat.state, VibeChat.update_context_buffer, VibeChat.append_to_output)
  return loaded_session
end

function VibeChat.sessions_save()
  return SessionManager.save(VibeChat.get_messages(), VibeChat.state)
end

function VibeChat.sessions_end_session()
  return SessionManager.end_session(VibeChat.get_messages(), VibeChat.state)
end

function VibeChat.sessions_list(callback)
  return SessionManager.list(callback)
end

function VibeChat.sessions_load_interactive()
  return VibeChat.load_session_interactive()
end

function VibeChat.sessions_delete_interactive()
  return VibeChat.delete_session_interactive()
end

function VibeChat.sessions_rename_interactive()
  return SessionManager.rename_interactive(VibeChat.append_to_output)
end

function VibeChat.sessions_get_most_recent()
  return SessionManager.get_most_recent()
end

function VibeChat.sessions_get_current_session_id()
  return SessionManager.current_session_id
end

-- Configure the chat module with CONFIG
VibeChat.configure(CONFIG)

-- =============================================================================
-- Setup Commands and Keymaps
-- =============================================================================
require 'vibe-coding.commands'(VibeChat, VibeDiff, VibePatcher, CONFIG)
require 'vibe-coding.keymaps'(VibeDiff, Utils)

-- Export the modules
return {
  CONFIG = CONFIG,
  VibeChat = VibeChat,
  VibeDiff = VibeDiff,
  Utils = Utils,
  VibePatcher = VibePatcher,
  Validation = Validation,
}
