-- PromptManager: Manages prompt selection and loading
local Utils = require 'vibe-coding.utils'

local PromptManager = {}

-- Table to keep prompt info: name -> file path
PromptManager.prompt_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h') .. '/prompts'
-- Set initial prompt on startup to friendly-diffs by default
PromptManager.selected_prompt_name = 'friendly-diffs'

local function load_prompts()
  local prompt_files = vim.fn.glob(PromptManager.prompt_dir .. '/*.md', false, true)
  local prompts = {}
  for _, file in ipairs(prompt_files) do
    local base = vim.fn.fnamemodify(file, ':t:r')
    prompts[#prompts + 1] = { name = base, path = file }
  end
  return prompts
end

-- Invoke telescope picker to select prompt with preview
function PromptManager.select_prompt(callback)
  local prompts = load_prompts()
  if #prompts == 0 then
    vim.notify('[Vibe] No prompts found in ' .. PromptManager.prompt_dir, vim.log.levels.ERROR)
    return
  end

  local previewers = require 'telescope.previewers'

  Utils.create_telescope_picker {
    prompt_title = 'Select Prompt',
    items = prompts,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry.name,
        ordinal = entry.name,
      }
    end,
    previewer = previewers.new_buffer_previewer {
      title = 'Prompt Preview',
      define_preview = function(self, entry)
        local filepath = entry.value.path
        if not filepath or vim.fn.filereadable(filepath) ~= 1 then
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { 'Prompt file not readable or missing' })
          return
        end

        local content, err = Utils.read_file(filepath)
        if not content then
          vim.api.nvim_buf_set_lines(
            self.state.bufnr,
            0,
            -1,
            false,
            { 'Error reading prompt: ' .. (err or 'Unknown error') }
          )
          return
        end

        local max_preview_lines = 400
        local preview_lines = {}
        for i = 1, math.min(#content, max_preview_lines) do
          table.insert(preview_lines, content[i])
        end
        if #content > max_preview_lines then
          table.insert(preview_lines, '...')
        end

        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)
        vim.bo[self.state.bufnr].filetype = 'markdown'
      end,
    },
    on_selection = function(selection)
      PromptManager.selected_prompt_name = selection.name
      vim.notify('[Vibe] Selected prompt: ' .. selection.name, vim.log.levels.INFO)
      if callback then
        callback(selection.name, selection.path)
      end
    end,
  }
end

-- Get content of selected prompt, fallback on unified-diffs.md
function PromptManager.get_prompt_content()
  local prompt_file = PromptManager.prompt_dir .. '/' .. PromptManager.selected_prompt_name .. '.md'
  if vim.fn.filereadable(prompt_file) ~= 1 then
    -- fallback to unified-diffs.md
    prompt_file = PromptManager.prompt_dir .. '/unified-diffs.md'
  end
  local lines, err = Utils.read_file(prompt_file)
  if not lines then
    vim.notify('[Vibe] Failed to read prompt file: ' .. err, vim.log.levels.ERROR)
    return ''
  end
  return table.concat(lines, '\n')
end

return PromptManager
