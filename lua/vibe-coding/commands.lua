-- vibe-coding/commands.lua
-- User command definitions for Vibe Coding

return function(VibeChat, VibeDiff, VibePatcher, CONFIG)
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
    'VibeAddBuffersToContext',
    VibeChat.add_buffer_context_to_chat,
    { desc = 'Add opened buffers to the Vibe chat context' }
  )
  vim.api.nvim_create_user_command(
    'VibeAddCurrentBuffer',
    VibeChat.add_current_buffer_to_context,
    { desc = 'Add the current buffer to the Vibe chat context' }
  )
  vim.api.nvim_create_user_command('VibeDiff', function()
    local code_block, err = VibeChat.get_relevant_code_block()
    if not code_block then
      vim.notify('[Vibe] ' .. (err or 'No suitable code block found'), vim.log.levels.WARN)
      return
    end

    VibeDiff.show(code_block, VibeChat.state.main_editor_win_id)
  end, { desc = 'Diff the last AI code block with the main editor buffer' })

  vim.api.nvim_create_user_command('VibeApplyPatch', function()
    VibePatcher.apply_patches_from_last_response(VibeChat.get_messages())
  end, { desc = 'Apply patches from the last AI response with full validation (stops on first failure)' })

  vim.api.nvim_create_user_command('VibeReviewPatch', function()
    VibePatcher.review_and_apply_patches_from_last_response(VibeChat.get_messages())
  end, { desc = 'Review and apply patches from the last AI response with validation and editing' })

  vim.api.nvim_create_user_command('VibeSessionStart', function(opts)
    local session_name = opts.args ~= '' and opts.args or nil
    VibeChat.sessions.start(session_name)
    -- If chat is not open, open it
    if not VibeChat.state.layout_active then
      VibeChat.open_chat_window()
    end
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

  -- User command to select prompt
  vim.api.nvim_create_user_command('VibePromptSelect', VibeChat.select_prompt, { desc = 'Select prompt for Vibe AI' })

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
end
