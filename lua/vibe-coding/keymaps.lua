-- vibe-coding/keymaps.lua
-- Keymap definitions for Vibe Coding

return function(VibeDiff, Utils)
  local keymap = vim.keymap.set

  -- Vibe coding keymaps
  keymap('n', '<leader>d ', ':VibeToggle<cr>', { noremap = true, desc = 'Toggle Window' })
  keymap('n', '<leader>da', ':VibeApplyPatch<cr>', { noremap = true, desc = 'Apply diff from last AI response' })
  keymap('n', '<leader>dA', ':VibeReviewPatch<cr>', { noremap = true, desc = 'Review and apply diff with validation' })
  keymap('n', '<leader>dc', ':GptInput<cr>', { noremap = true, desc = 'Oneoff Chat' })
  keymap('n', '<leader>db', ':VibeAddCurrentBuffer<cr>', { noremap = true, desc = 'Add current buffer to context' })
  keymap('n', '<leader>df', ':VibeAddToContext<cr>', { noremap = true, desc = 'Add file to context' })
  keymap('n', '<leader>dx', ':VibeRemoveFromContext<cr>', { noremap = true, desc = 'Remove file from context' })
  keymap('n', '<leader>dd', ':VibeChat<cr>', { noremap = true, desc = 'Vibe Chat' })
  keymap('n', '<leader>dv', ':VibeDiff<cr>', { noremap = true, desc = 'Show diff with AI suggestion' })
  keymap('n', '<leader>d?', ':VibeDebugToggle<cr>', { noremap = true, desc = 'Toggle debug mode' })
  keymap('n', '<leader>dq', function()
    VibeDiff.cleanup_diff_buffers()
    vim.cmd 'diffoff!'
  end, { desc = 'Close diff and cleanup' })

  -- VibeSession management keybindings
  keymap('n', '<leader>dn', ':VibeSessionStart<cr>', { noremap = true, desc = 'Start new Vibe session' })
  keymap('n', '<leader>dl', ':VibeSessionLoad<cr>', { noremap = true, desc = 'Load Vibe session' })
  keymap('n', '<leader>dm', ':VibeSessionDelete<cr>', { noremap = true, desc = 'Delete Vibe session' })
  keymap('n', '<leader>dr', ':VibeSessionRename<cr>', { noremap = true, desc = 'Rename Vibe session' })

  keymap('n', '<leader>dp', ':VibePromptSelect<cr>', { noremap = true, desc = 'Select Vibe prompt' })
  keymap('n', '<leader>du', Utils.update_openai_api_key, { noremap = true, desc = 'Update OpenAI api key' })
end