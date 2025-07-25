-- VibeContext: Manages adding file context using Telescope
local Utils = require 'vibe-coding.utils'

local VibeContext = {}

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

-- Add buffer context picker
function VibeContext.add_buffers_to_context(callback)
  local telescope = require 'telescope.builtin'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  telescope.buffers {
    prompt_title = 'Select buffers for context (Tab to multi-select)',
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selections = {}
        local picker = action_state.get_current_picker(prompt_bufnr)

        -- Get multi-selected buffers
        local multi_selection = picker:get_multi_selection()
        if #multi_selection > 0 then
          for _, entry in ipairs(multi_selection) do
            local bufnr = entry.bufnr
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name and name ~= '' then
              table.insert(selections, name)
            end
          end
        else
          -- Get single selection if no multi-selection
          local entry = action_state.get_selected_entry()
          if entry then
            local bufnr = entry.bufnr
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name and name ~= '' then
              table.insert(selections, name)
            end
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

function VibeContext.remove_file_from_context(context_files, callback)
  if #context_files == 0 then
    vim.notify('[Vibe] No context files to remove', vim.log.levels.WARN)
    return
  end

  local file_map = {}
  local display_entries = {}
  for _, file_path in ipairs(context_files) do
    local display_path = Utils.get_relative_path(file_path)
    table.insert(display_entries, display_path)
    file_map[display_path] = file_path
  end

  Utils.create_telescope_picker {
    prompt_title = 'Remove files from context (Tab to multi-select)',
    items = display_entries,
    previewer = require('telescope.previewers').new_buffer_previewer {
      title = 'File Preview',
      define_preview = function(self, entry)
        local filepath = file_map[entry.value]
        if not filepath or vim.fn.filereadable(filepath) ~= 1 then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { 'File not readable or does not exist' })
          return
        end

        local content, err = Utils.read_file_content(filepath)
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

        local lines = vim.split(content, '\n')
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

        local filetype = vim.filetype.match { filename = filepath }
        if filetype then
          vim.bo[self.state.bufnr].filetype = filetype
        end
      end,
    },
    on_selection = function(selection)
      callback { file_map[selection] }
    end,
    on_multi_selection = function(selections)
      local result = {}
      for _, sel in ipairs(selections) do
        table.insert(result, file_map[sel])
      end
      callback(result)
    end,
  }
end

return VibeContext
