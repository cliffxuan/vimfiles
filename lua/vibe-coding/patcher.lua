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

--- Validates and fixes common issues in diff content.
-- @param diff_content The raw diff content to validate.
-- @return string, table: The cleaned diff content and a table of issues found.
function VibePatcher.validate_and_fix_diff(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local issues = {}
  local fixed_lines = {}

  -- Track state for validation
  local has_header = false
  local in_hunk = false
  local hunk_line_count = { old = 0, new = 0 }
  local expected_counts = { old = 0, new = 0 }

  for i, line in ipairs(lines) do
    local fixed_line = line

    -- Check for diff headers
    if line:match '^---' or line:match '^%+%+%+' then
      has_header = true
      -- Fix common header issues
      if line:match '^---%s*$' then
        fixed_line = '--- /dev/null'
        table.insert(issues, { line = i, type = 'header', message = 'Fixed empty old file header' })
      elseif line:match '^%+%+%+%s*$' then
        fixed_line = '+++ /dev/null'
        table.insert(issues, { line = i, type = 'header', message = 'Fixed empty new file header' })
      end
    -- Check for hunk headers
    elseif line:match '^@@' then
      in_hunk = true
      local old_start, old_count, new_start, new_count = line:match '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@'

      if not old_start then
        -- Try simpler format without counts
        old_start, new_start = line:match '^@@ %-(%d+) %+(%d+) @@'
        if old_start then
          old_count, new_count = '1', '1'
          fixed_line = string.format('@@ -%s,1 +%s,1 @@', old_start, new_start)
          table.insert(issues, { line = i, type = 'hunk_header', message = 'Added missing line counts' })
        else
          table.insert(
            issues,
            { line = i, type = 'hunk_header', message = 'Malformed hunk header', severity = 'error' }
          )
        end
      end

      -- Parse expected counts
      expected_counts.old = tonumber(old_count) or 0
      expected_counts.new = tonumber(new_count) or 0
      hunk_line_count = { old = 0, new = 0 }

    -- Check context and change lines
    elseif in_hunk then
      local op = line:sub(1, 1)

      if op == ' ' or op == '' then
        -- Context line
        hunk_line_count.old = hunk_line_count.old + 1
        hunk_line_count.new = hunk_line_count.new + 1
        -- Fix missing space prefix for context lines
        if op == '' and line ~= '' then
          fixed_line = ' ' .. line
          table.insert(issues, { line = i, type = 'context', message = 'Added missing space prefix for context line' })
        end
      elseif op == '-' then
        -- Removed line
        hunk_line_count.old = hunk_line_count.old + 1
      elseif op == '+' then
        -- Added line
        hunk_line_count.new = hunk_line_count.new + 1
      else
        -- Invalid line in hunk
        if line ~= '' then
          table.insert(
            issues,
            { line = i, type = 'invalid_line', message = 'Invalid line in hunk: ' .. line, severity = 'warning' }
          )
        end
      end
    end

    table.insert(fixed_lines, fixed_line)
  end

  -- Final validation
  if not has_header then
    table.insert(
      issues,
      { line = 1, type = 'missing_header', message = 'Diff missing file headers', severity = 'error' }
    )
  end

  return table.concat(fixed_lines, '\n'), issues
end

--- Formats diff content for better readability and standards compliance.
-- @param diff_content The diff content to format.
-- @return string: The formatted diff content.
function VibePatcher.format_diff(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local formatted_lines = {}

  for _, line in ipairs(lines) do
    -- Ensure proper spacing in headers
    if line:match '^---' then
      local file_path = line:match '^---%s*(.*)$'
      if file_path and file_path ~= '' then
        table.insert(formatted_lines, '--- ' .. file_path)
      else
        table.insert(formatted_lines, '--- /dev/null')
      end
    elseif line:match '^%+%+%+' then
      local file_path = line:match '^%+%+%+%s*(.*)$'
      if file_path and file_path ~= '' then
        table.insert(formatted_lines, '+++ ' .. file_path)
      else
        table.insert(formatted_lines, '+++ /dev/null')
      end
    else
      table.insert(formatted_lines, line)
    end
  end

  return table.concat(formatted_lines, '\n')
end

--- Tests if a diff can be applied using external tools.
-- @param diff_content The diff content to test.
-- @param target_file The file to test against.
-- @return boolean, string: Success status and any error message.
function VibePatcher.test_diff_with_external_tool(diff_content, target_file)
  -- Create temporary diff file
  local temp_diff = vim.fn.tempname() .. '.diff'
  local success, write_err = Utils.write_file(temp_diff, vim.split(diff_content, '\n'))
  if not success then
    return false, 'Failed to create temporary diff file: ' .. (write_err or '')
  end

  -- Test with git apply --check (if in git repo)
  local is_git_repo = vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null'):match 'true'
  if is_git_repo then
    local git_result = vim.fn.system(string.format('git apply --check %s 2>&1', vim.fn.shellescape(temp_diff)))
    local git_exit_code = vim.v.shell_error

    vim.fn.delete(temp_diff)

    if git_exit_code == 0 then
      return true, 'Git apply validation passed'
    else
      return false, 'Git apply validation failed: ' .. git_result
    end
  end

  -- Fallback to patch command dry run
  local patch_result = vim.fn.system(
    string.format('patch --dry-run %s < %s 2>&1', vim.fn.shellescape(target_file), vim.fn.shellescape(temp_diff))
  )
  local patch_exit_code = vim.v.shell_error

  vim.fn.delete(temp_diff)

  if patch_exit_code == 0 then
    return true, 'Patch command validation passed'
  else
    return false, 'Patch command validation failed: ' .. patch_result
  end
end

--- Opens an interactive diff review window for user editing and validation.
-- @param diff_content The diff content to review.
-- @param issues A table of validation issues found.
-- @param callback Function to call with the final diff content (or nil if cancelled).
function VibePatcher.review_diff_interactive(diff_content, issues, callback)
  -- Create a new buffer for diff editing
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Vibe Diff Review')

  -- Set up the diff content with issue annotations
  local lines = vim.split(diff_content, '\n')
  local annotated_lines = {}

  -- Add header with instructions
  table.insert(annotated_lines, '# Vibe Diff Review - Edit and validate the diff below')
  table.insert(annotated_lines, '# Issues found: ' .. #issues)
  table.insert(annotated_lines, '# Commands: :VibeApplyDiff (apply), :q (cancel)')
  table.insert(annotated_lines, '# External validation will be run before applying')
  table.insert(annotated_lines, '')

  -- Add issue summary
  if #issues > 0 then
    table.insert(annotated_lines, '# Issues found:')
    for _, issue in ipairs(issues) do
      local severity = issue.severity or 'info'
      local prefix = severity == 'error' and 'ERROR' or (severity == 'warning' and 'WARN' or 'INFO')
      table.insert(annotated_lines, string.format('# Line %d [%s]: %s', issue.line, prefix, issue.message))
    end
    table.insert(annotated_lines, '')
  end

  table.insert(annotated_lines, '# ===== DIFF CONTENT BELOW =====')

  -- Add the actual diff content with line numbers for issue reference
  local diff_start_line = #annotated_lines + 1
  for i, line in ipairs(lines) do
    -- Check if this line has issues
    local line_issues = {}
    for _, issue in ipairs(issues) do
      if issue.line == i then
        table.insert(line_issues, issue)
      end
    end

    -- Add issue comments above problematic lines
    for _, issue in ipairs(line_issues) do
      local severity = issue.severity or 'info'
      local prefix = severity == 'error' and 'ERROR' or (severity == 'warning' and 'WARN' or 'INFO')
      table.insert(annotated_lines, string.format('# [%s] %s', prefix, issue.message))
    end

    table.insert(annotated_lines, line)
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, annotated_lines)
  vim.bo[buf].filetype = 'diff'
  vim.bo[buf].modifiable = true

  -- Open in a new tab
  vim.cmd 'tabnew'
  vim.api.nvim_win_set_buf(0, buf)

  -- Set up keymaps for the review buffer
  local function create_review_keymap_opts()
    return { noremap = true, silent = true, buffer = buf }
  end

  -- Create apply command for this buffer
  vim.api.nvim_buf_create_user_command(buf, 'VibeApplyDiff', function()
    -- Extract diff content (everything after the header)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local diff_lines = {}
    local in_diff = false

    for _, line in ipairs(all_lines) do
      if line == '# ===== DIFF CONTENT BELOW =====' then
        in_diff = true
      elseif in_diff and not line:match '^#' then
        table.insert(diff_lines, line)
      end
    end

    local final_diff = table.concat(diff_lines, '\n')

    -- Close the review tab
    vim.cmd 'tabclose'

    -- Call the callback with the edited diff
    if callback then
      callback(final_diff)
    end
  end, { desc = 'Apply the reviewed diff' })

  -- Cancel keymap
  vim.keymap.set('n', 'q', function()
    vim.cmd 'tabclose'
    if callback then
      callback(nil) -- nil indicates cancellation
    end
  end, create_review_keymap_opts())

  -- Validate keymap
  vim.keymap.set('n', '<leader>v', function()
    -- Extract current diff content and validate
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local diff_lines = {}
    local in_diff = false

    for _, line in ipairs(all_lines) do
      if line == '# ===== DIFF CONTENT BELOW =====' then
        in_diff = true
      elseif in_diff and not line:match '^#' then
        table.insert(diff_lines, line)
      end
    end

    local current_diff = table.concat(diff_lines, '\n')
    local fixed_diff, new_issues = VibePatcher.validate_and_fix_diff(current_diff)

    if #new_issues == 0 then
      vim.notify('[Vibe] Diff validation passed!', vim.log.levels.INFO)
    else
      local error_count = 0
      local warning_count = 0
      for _, issue in ipairs(new_issues) do
        if issue.severity == 'error' then
          error_count = error_count + 1
        else
          warning_count = warning_count + 1
        end
      end
      vim.notify(
        string.format('[Vibe] Validation found %d errors, %d warnings', error_count, warning_count),
        vim.log.levels.WARN
      )
    end
  end, create_review_keymap_opts())

  vim.notify('[Vibe] Diff review opened. Edit as needed, then :VibeApplyDiff or q to cancel', vim.log.levels.INFO)
end

--- Applies a diff using external tools when possible.
-- @param diff_content The diff content to apply.
-- @param target_file The file to apply the diff to.
-- @return boolean, string: Success status and message.
function VibePatcher.apply_with_external_tool(diff_content, target_file)
  -- Create temporary diff file
  local temp_diff = vim.fn.tempname() .. '.diff'
  local success, write_err = Utils.write_file(temp_diff, vim.split(diff_content, '\n'))
  if not success then
    return false, 'Failed to create temporary diff file: ' .. (write_err or '')
  end

  -- Try git apply first (if in git repo)
  local is_git_repo = vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null'):match 'true'
  if is_git_repo then
    local git_result = vim.fn.system(string.format('git apply %s 2>&1', vim.fn.shellescape(temp_diff)))
    local git_exit_code = vim.v.shell_error

    if git_exit_code == 0 then
      vim.fn.delete(temp_diff)
      return true, 'Applied successfully with git apply'
    else
      -- Git apply failed, fall through to patch command
      vim.notify('[Vibe] Git apply failed, trying patch command: ' .. git_result, vim.log.levels.WARN)
    end
  end

  -- Try patch command
  local patch_result =
    vim.fn.system(string.format('patch %s < %s 2>&1', vim.fn.shellescape(target_file), vim.fn.shellescape(temp_diff)))
  local patch_exit_code = vim.v.shell_error

  vim.fn.delete(temp_diff)

  if patch_exit_code == 0 then
    return true, 'Applied successfully with patch command'
  else
    return false, 'External tool application failed: ' .. patch_result
  end
end

--- Reviews and applies diffs from the last AI response with validation.
function VibePatcher.review_and_apply_last_response(messages)
  local last_ai_message = nil
  for i = #messages, 1, -1 do
    if messages[i].role == 'assistant' then
      last_ai_message = messages[i].content
      break
    end
  end

  if not last_ai_message then
    vim.notify('[Vibe] No AI response found to review.', vim.log.levels.WARN)
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

  -- Process each diff block with validation
  for i, diff_content in ipairs(diff_blocks) do
    -- Validate and fix the diff
    local fixed_diff, issues = VibePatcher.validate_and_fix_diff(diff_content)
    local formatted_diff = VibePatcher.format_diff(fixed_diff)

    -- Show issues summary
    if #issues > 0 then
      local error_count = 0
      local warning_count = 0
      for _, issue in ipairs(issues) do
        if issue.severity == 'error' then
          error_count = error_count + 1
        else
          warning_count = warning_count + 1
        end
      end
      vim.notify(
        string.format('[Vibe] Diff %d/%d: Found %d errors, %d warnings', i, #diff_blocks, error_count, warning_count),
        vim.log.levels.INFO
      )
    end

    -- Open interactive review
    VibePatcher.review_diff_interactive(formatted_diff, issues, function(final_diff)
      if not final_diff then
        vim.notify('[Vibe] Diff review cancelled', vim.log.levels.INFO)
        return
      end

      -- Parse and apply the final diff
      local parsed_diff, parse_err = VibePatcher.parse_diff(final_diff)
      if not parsed_diff then
        vim.notify('[Vibe] Failed to parse reviewed diff: ' .. (parse_err or ''), vim.log.levels.ERROR)
        return
      end

      -- Test with external tool first
      local can_apply_external, external_msg =
        VibePatcher.test_diff_with_external_tool(final_diff, parsed_diff.new_path)

      if can_apply_external then
        -- Ask user to choose application method
        vim.ui.select(
          { 'External Tool (git apply/patch)', 'Built-in Engine' },
          { prompt = 'Choose diff application method:' },
          function(choice)
            if choice == 'External Tool (git apply/patch)' then
              local success, msg = VibePatcher.apply_with_external_tool(final_diff, parsed_diff.new_path)
              if success then
                vim.notify('[Vibe] ' .. msg, vim.log.levels.INFO)
                -- Refresh buffer
                VibePatcher.refresh_buffer_for_file(parsed_diff.new_path)
              else
                vim.notify('[Vibe] ' .. msg, vim.log.levels.ERROR)
              end
            elseif choice == 'Built-in Engine' then
              local success, msg = VibePatcher.apply_diff(parsed_diff)
              if success then
                vim.notify('[Vibe] ' .. msg, vim.log.levels.INFO)
              else
                vim.notify('[Vibe] ' .. msg, vim.log.levels.ERROR)
              end
            end
          end
        )
      else
        vim.notify('[Vibe] External validation failed: ' .. external_msg, vim.log.levels.WARN)
        vim.notify('[Vibe] Falling back to built-in engine', vim.log.levels.INFO)

        local success, msg = VibePatcher.apply_diff(parsed_diff)
        if success then
          vim.notify('[Vibe] ' .. msg, vim.log.levels.INFO)
        else
          vim.notify('[Vibe] ' .. msg, vim.log.levels.ERROR)
        end
      end
    end)

    -- Only process one diff at a time for now
    break
  end
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
