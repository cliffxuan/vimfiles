-- vibe-coding/utils.lua
-- Utility functions for vibe-coding plugin

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

function Utils.read_file_content(filepath)
  local content, err = Utils.read_file(filepath)
  if not content then
    return nil, err
  end
  return table.concat(content, '\n'), nil
end

function Utils.write_file(filepath, content)
  local ok, _ = pcall(vim.fn.writefile, content, filepath)
  if not ok then
    return false, 'Failed to write file: ' .. filepath
  end
  return true, nil
end

-- Helper: split path into components
function Utils.split_path(path)
  local parts = {}
  for part in string.gmatch(path, '[^/]+') do
    table.insert(parts, part)
  end
  return parts
end

-- Helper: compute relative path from 'from' to 'to'
function Utils.path_relative(from, to)
  local from_parts = Utils.split_path(from)
  local to_parts = Utils.split_path(to)

  -- Find common prefix length
  local i = 1
  while i <= #from_parts and i <= #to_parts and from_parts[i] == to_parts[i] do
    i = i + 1
  end
  i = i - 1 -- last common index

  -- Construct relative path
  local rel_parts = {}

  -- Up from 'from' remaining parts
  for _ = i + 1, #from_parts do
    table.insert(rel_parts, '..')
  end

  -- Down into 'to' remaining parts
  for j = i + 1, #to_parts do
    table.insert(rel_parts, to_parts[j])
  end

  if #rel_parts == 0 then
    return '.' -- same path
  else
    return table.concat(rel_parts, '/')
  end
end

-- Get relative path for display purposes (extracted from repeated code)
function Utils.get_relative_path(file_path)
  -- Check if file is in a git repo and get relative path if possible
  local file_dir = vim.fn.fnamemodify(file_path, ':h')
  local git_root_cmd = 'cd ' .. vim.fn.shellescape(file_dir) .. ' && git rev-parse --show-toplevel 2>/dev/null'
  local git_root = vim.fn.trim(vim.fn.system(git_root_cmd))

  local display_path = file_path
  if git_root ~= '' and vim.v.shell_error == 0 then
    display_path = Utils.path_relative(git_root, file_path)
  end

  return display_path
end

function Utils.update_openai_api_key()
  -- Read the API key from file
  local keyfile = vim.fn.expand '$HOME/.config/openai_api_key'
  if vim.fn.filereadable(keyfile) ~= 1 then
    vim.notify('[Vibe] API key file not found: ' .. keyfile, vim.log.levels.ERROR)
    return
  end

  local api_key_lines = vim.fn.readfile(keyfile)
  if not api_key_lines or #api_key_lines == 0 then
    vim.notify('[Vibe] API key file is empty: ' .. keyfile, vim.log.levels.ERROR)
    return
  end

  local api_key = api_key_lines[1]:gsub('%s+', '') -- trim whitespace
  if api_key == '' then
    vim.notify('[Vibe] API key is empty after trimming.', vim.log.levels.ERROR)
    return
  end

  -- Obfuscate printing of API key except last 4 characters
  local num_dots = math.max(0, #api_key - 4)
  local obfuscated_key = string.rep('.', num_dots) .. api_key:sub(-4)

  vim.env.OPENAI_API_KEY = api_key
  -- Need to access CONFIG from the main module
  local vibe = package.loaded['vibe-coding']
  if vibe and vibe.CONFIG then
    vibe.CONFIG.api_key = api_key
  end
  vim.notify('[Vibe] OpenAI API key updated: ' .. obfuscated_key, vim.log.levels.INFO)
end

function Utils.create_telescope_picker(opts)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local conf = require('telescope.config').values

  local picker_opts = {
    prompt_title = opts.prompt_title,
    finder = finders.new_table {
      results = opts.items,
      entry_maker = opts.entry_maker or function(entry)
        return {
          value = entry,
          display = entry,
          ordinal = entry,
        }
      end,
    },
    sorter = conf.generic_sorter {},
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          if opts.on_selection then
            opts.on_selection(selection.value)
          elseif opts.on_select then
            opts.on_select(selection.value)
          end
        end
      end)

      -- Handle multi-selection
      if opts.on_multi_selection and not opts.disable_multi_selection then
        map('i', '<Tab>', function()
          actions.toggle_selection(prompt_bufnr)
        end)

        map('n', '<space>', function()
          actions.toggle_selection(prompt_bufnr)
        end)

        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local multi_selection = picker:get_multi_selection()
          actions.close(prompt_bufnr)

          if #multi_selection > 0 then
            local selections = {}
            for _, entry in ipairs(multi_selection) do
              table.insert(selections, entry.value)
            end
            opts.on_multi_selection(selections)
          else
            local selection = action_state.get_selected_entry()
            if selection then
              if opts.on_selection then
                opts.on_selection(selection.value)
              elseif opts.on_select then
                opts.on_select(selection.value)
              end
            end
          end
        end)
      end

      -- Disable multi-selection keybinding if requested
      if opts.disable_multi_selection then
        actions.toggle_selection:replace(function() end)
      end

      return true
    end,
  }

  -- Add previewer if provided
  if opts.previewer then
    picker_opts.previewer = opts.previewer
  end

  pickers.new({}, picker_opts):find()
end

return Utils
