-- vibe-coding/patcher.lua
local Utils = require 'vibe-coding.utils'

local VibePatcher = {}

--- Parses a single unified diff block.
-- @param diff_content The string content of the diff.
-- @return A table with parsed diff info, or nil and an error message.
function VibePatcher.parse_diff(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local diff = { hunks = {} }

  if #lines < 3 then
    return nil, 'Diff content is too short to be valid.'
  end

  -- More robust path parsing
  diff.old_path = lines[1]:match '^---%s+a/(.*)$' or lines[1]:match '^---%s+(.*)$'
  diff.new_path = lines[2]:match '^%+%+%+%s+b/(.*)$' or lines[2]:match '^%+%+%+%s+(.*)$'

  if not diff.old_path or not diff.new_path then
    return nil, 'Could not parse file paths from diff header.\nHeader was:\n' .. lines[1] .. '\n' .. lines[2]
  end

  -- Trim trailing whitespace from paths
  diff.old_path = diff.old_path:gsub('%s+$', '')
  diff.new_path = diff.new_path:gsub('%s+$', '')

  local current_hunk = nil
  local line_num = 3
  while line_num <= #lines do
    local line = lines[line_num]
    if line:match '^@@' then
      if current_hunk then
        table.insert(diff.hunks, current_hunk)
      end
      current_hunk = { header = line, lines = {} }
    elseif current_hunk and (line:match '^[-+]' or line:match '^%s' or line == ' ') then -- Include context lines for better error reporting
      table.insert(current_hunk.lines, line)
    elseif
      current_hunk
      and line ~= ''
      and not line:match '^@@'
      and not line:match '^---'
      and not line:match '^%+%+%+'
    then
      -- This is likely a context line missing the leading space, mark it specially
      table.insert(current_hunk.lines, '~' .. line)
    elseif current_hunk and #current_hunk.lines > 0 then
      -- End of hunk, maybe some trailing text from LLM.
      table.insert(diff.hunks, current_hunk)
      current_hunk = nil -- Stop collecting
    end
    line_num = line_num + 1
  end

  if current_hunk and #current_hunk.lines > 0 then
    table.insert(diff.hunks, current_hunk)
  end

  if #diff.hunks == 0 then
    return nil, 'Diff contains no hunks or changes.'
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
    -- TODO: Handle file deletion
    return true, 'Skipped file deletion for ' .. parsed_diff.old_path
  end

  local original_lines
  local is_new_file = (parsed_diff.old_path == '/dev/null')

  if is_new_file then
    original_lines = {}
  else
    local content, err = Utils.read_file_content(parsed_diff.old_path)
    if not content then
      return false, 'Failed to read file ' .. parsed_diff.old_path .. ': ' .. (err or 'Unknown Error')
    end
    original_lines = vim.split(content, '\n', { plain = true, trimempty = false })
  end

  local modified_lines = vim.deepcopy(original_lines)
  local offset = 0

  for hunk_idx, hunk in ipairs(parsed_diff.hunks) do
    local context_before = {}
    local context_after = {}
    local to_remove = {}
    local to_add = {}
    local in_changes = false

    -- Build search pattern preserving original line order
    -- This fixes the bug where removed lines were reordered incorrectly
    local search_lines = {}
    local replacement_lines = {}

    -- First pass: build search pattern (context + removals only)
    for _, line in ipairs(hunk.lines) do
      local op = line:sub(1, 1)
      local text

      -- Handle empty context lines correctly
      if #line == 1 and op == ' ' then
        -- Empty context line (just a single space)
        text = ''
      elseif op == '~' then
        -- This was a context line missing the leading space
        text = line:sub(2)
        op = ' ' -- Treat as context line
      else
        text = line:sub(2)
      end

      if op == ' ' then
        -- Context lines go in both search and replacement
        table.insert(search_lines, text)
        table.insert(replacement_lines, text)
      elseif op == '-' then
        -- Removed lines only go in search pattern
        table.insert(search_lines, text)
      elseif op == '+' then
        -- Added lines only go in replacement
        table.insert(replacement_lines, text)
      end
    end

    -- Separate traditional arrays for backward compatibility
    for _, line in ipairs(hunk.lines) do
      local op = line:sub(1, 1)
      local text

      -- Handle empty context lines correctly
      if #line == 1 and op == ' ' then
        text = ''
      elseif op == '~' then
        -- This was a context line missing the leading space
        text = line:sub(2)
        op = ' ' -- Treat as context line
      else
        text = line:sub(2)
      end

      if op == ' ' then
        if in_changes then
          table.insert(context_after, text)
        else
          table.insert(context_before, text)
        end
      elseif op == '-' then
        in_changes = true
        table.insert(to_remove, text)
      elseif op == '+' then
        in_changes = true
        table.insert(to_add, text)
      end
    end

    local hunk_processed = false

    if #search_lines == 0 and #to_add > 0 and #to_remove == 0 then -- Pure addition with no removals
      -- For pure additions, we can insert at the end. This is a simplification.
      -- A more robust solution would use the line numbers from `@@ -l,c +l,c @@`
      for _, line in ipairs(to_add) do
        table.insert(modified_lines, line)
      end
      offset = offset + #to_add
      hunk_processed = true
    end

    if not hunk_processed then
      local found_at = -1

      -- First try exact matching
      for i = 1, #modified_lines - #search_lines + 1 do
        local match = true
        for j = 1, #search_lines do
          if modified_lines[i + j - 1] ~= search_lines[j] then
            match = false
            break
          end
        end
        if match then
          found_at = i
          break
        end
      end

      -- If exact match fails, try fuzzy matching that skips blank lines
      if found_at == -1 then
        -- Create non-blank line patterns for fuzzy matching
        local search_non_blank = {}
        local search_non_blank_indices = {}
        for i, line in ipairs(search_lines) do
          if line ~= '' then
            table.insert(search_non_blank, line)
            table.insert(search_non_blank_indices, i)
          end
        end

        -- Only try fuzzy matching if we have non-blank lines to match
        if #search_non_blank > 0 then
          for start_pos = 1, #modified_lines do
            local file_non_blank = {}
            local file_non_blank_indices = {}
            local end_pos = start_pos

            -- Collect non-blank lines from file starting at start_pos
            for i = start_pos, #modified_lines do
              if modified_lines[i] ~= '' then
                table.insert(file_non_blank, modified_lines[i])
                table.insert(file_non_blank_indices, i)
                if #file_non_blank == #search_non_blank then
                  end_pos = i
                  break
                end
              end
              -- Stop if we've gone too far without finding enough non-blank lines
              if i - start_pos > #search_lines + 10 then
                break
              end
            end

            -- Check if non-blank lines match
            if #file_non_blank == #search_non_blank then
              local fuzzy_match = true
              for j = 1, #search_non_blank do
                if file_non_blank[j] ~= search_non_blank[j] then
                  fuzzy_match = false
                  break
                end
              end

              if fuzzy_match then
                found_at = start_pos

                -- Adjust search_lines to match the actual span we found
                search_lines = {}
                for i = start_pos, end_pos do
                  table.insert(search_lines, modified_lines[i])
                end

                -- For fuzzy matching, rebuild replacement_lines by taking the original file content
                -- and applying just the additions from the diff
                replacement_lines = {}

                -- Start with the original matched content
                for i = start_pos, end_pos do
                  table.insert(replacement_lines, modified_lines[i])
                end

                -- Now apply additions - find where to insert them
                -- Look for the pattern in the diff to determine insertion point
                local additions = {}
                for _, line in ipairs(hunk.lines) do
                  local op = line:sub(1, 1)
                  if op == '+' then
                    local text = (#line == 1) and '' or line:sub(2)
                    table.insert(additions, text)
                  end
                end

                -- Find insertion point by matching the context before additions
                if #additions > 0 then
                  -- Find the context line that comes immediately before the addition in the diff
                  local insertion_after_line = nil
                  for i = 1, #hunk.lines - 1 do
                    local current_line = hunk.lines[i]
                    local next_line = hunk.lines[i + 1]
                    local current_op = current_line:sub(1, 1)
                    local next_op = next_line:sub(1, 1)

                    -- If current line is context and next line is addition
                    if current_op == ' ' and next_op == '+' then
                      insertion_after_line = (#current_line == 1) and '' or current_line:sub(2)
                      break
                    end
                  end

                  -- Find this line in our replacement and insert additions after it
                  if insertion_after_line then
                    for i, line in ipairs(replacement_lines) do
                      if line == insertion_after_line then
                        -- Insert additions after this line, but after any blank lines
                        local insert_pos = i + 1
                        -- Skip over blank lines to find the right insertion point
                        while insert_pos <= #replacement_lines and replacement_lines[insert_pos] == '' do
                          insert_pos = insert_pos + 1
                        end
                        for j, addition in ipairs(additions) do
                          table.insert(replacement_lines, insert_pos + j - 1, addition)
                        end
                        break
                      end
                    end
                  end
                end
                break
              end
            end
          end
        end
      end

      if found_at > -1 then
        -- Use the pre-built replacement lines that preserve order
        -- Remove the old lines
        for _ = 1, #search_lines do
          table.remove(modified_lines, found_at)
        end

        -- Insert the new lines (replacement_lines already built in correct order)
        for i, line in ipairs(replacement_lines) do
          table.insert(modified_lines, found_at + i - 1, line)
        end

        offset = offset + (#replacement_lines - #search_lines)
        hunk_processed = true
      else
        local error_msg = 'Failed to apply hunk #' .. hunk_idx .. ' to ' .. target_file .. '.\n'
        error_msg = error_msg .. 'Hunk content:\n' .. table.concat(hunk.lines, '\n') .. '\n\n'
        error_msg = error_msg .. 'Searching for pattern:\n' .. table.concat(search_lines, '\n') .. '\n\n'
        error_msg = error_msg .. 'Could not find this context in the file.'
        return false, error_msg
      end
    end

    if not hunk_processed then
      return false, 'Hunk #' .. hunk_idx .. ' was not processed successfully.'
    end
  end

  local success, write_err = Utils.write_file(target_file, modified_lines)
  if not success then
    return false, 'Failed to write changes to ' .. target_file .. ': ' .. (write_err or 'Unknown Error')
  end

  -- Refresh any open buffers for this file
  VibePatcher.refresh_buffer_for_file(target_file)

  return true, 'Successfully applied ' .. #parsed_diff.hunks .. ' hunks to ' .. target_file
end

--- Refreshes any open buffer that corresponds to the given file path.
-- @param filepath The absolute path to the file that was modified.
function VibePatcher.refresh_buffer_for_file(filepath)
  -- Get the absolute path to ensure proper matching
  local abs_filepath = vim.fn.fnamemodify(filepath, ':p')
  -- Find all buffers that match this file
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf_id) and vim.api.nvim_buf_is_loaded(buf_id) then
      local buf_name = vim.api.nvim_buf_get_name(buf_id)
      if buf_name ~= '' then
        local abs_buf_name = vim.fn.fnamemodify(buf_name, ':p')
        if abs_buf_name == abs_filepath then
          -- Check if buffer has been modified
          local modified = vim.bo[buf_id].modified
          if modified then
            -- Ask user what to do with modified buffer
            local choice = vim.fn.confirm(
              'Buffer for "'
                .. vim.fn.fnamemodify(filepath, ':t')
                .. '" has unsaved changes.\nReload with patch changes?',
              '&Reload\n&Keep current\n&Cancel',
              1
            )
            if choice == 1 then -- Reload
              vim.api.nvim_buf_call(buf_id, function()
                vim.cmd 'edit!'
              end)
              vim.notify('[Vibe] Reloaded buffer: ' .. vim.fn.fnamemodify(filepath, ':t'), vim.log.levels.INFO)
            elseif choice == 2 then -- Keep current
              vim.notify(
                '[Vibe] Kept current buffer changes: ' .. vim.fn.fnamemodify(filepath, ':t'),
                vim.log.levels.INFO
              )
            end
            -- choice == 3 (Cancel) does nothing
          else
            -- Buffer is not modified, safe to reload
            vim.api.nvim_buf_call(buf_id, function()
              vim.cmd 'edit!'
            end)
            vim.notify('[Vibe] Refreshed buffer: ' .. vim.fn.fnamemodify(filepath, ':t'), vim.log.levels.INFO)
          end
        end
      end
    end
  end
end
--- Extracts code blocks from markdown text content.
-- @param content The text content to search for code blocks.
-- @return A table of code blocks with their metadata.
function VibePatcher.extract_code_blocks(content)
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

--- Finds the last AI response, extracts diffs, and applies them.
function VibePatcher.apply_last_response(messages)
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

  local code_blocks = VibePatcher.extract_code_blocks(last_ai_message)
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

return VibePatcher
