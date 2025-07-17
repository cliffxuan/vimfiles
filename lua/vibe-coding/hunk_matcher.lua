-- vibe-coding/hunk_matcher.lua
-- Hunk matching and application logic

local Utils = require 'vibe-coding.utils'

local HunkMatcher = {}
HunkMatcher.__index = HunkMatcher

--- Creates a new HunkMatcher instance
-- @param parsed_diff The parsed diff to apply
-- @param options Options for application
-- @return HunkMatcher: New instance
function HunkMatcher.new(parsed_diff, options)
  local self = setmetatable({}, HunkMatcher)
  self.parsed_diff = parsed_diff
  self.options = options or {}
  self.split_hunks = self.options.split_hunks or false
  self.applied_hunks = 0
  self.failed_hunks = {}
  self.offset = 0
  return self
end

--- Applies all hunks in the diff
-- @return boolean, string: Success status and message
function HunkMatcher:apply_all_hunks()
  local target_file = self.parsed_diff.new_path
  if target_file == '/dev/null' then
    return true, 'Skipped file deletion for ' .. self.parsed_diff.old_path
  end

  -- Read original file content
  local original_lines = self:_read_original_file()
  if not original_lines then
    return false, 'Failed to read original file'
  end

  local modified_lines = vim.deepcopy(original_lines)

  -- Apply each hunk
  for hunk_idx, hunk in ipairs(self.parsed_diff.hunks) do
    local success = self:_apply_single_hunk(hunk, hunk_idx, modified_lines)
    if not success and not self.split_hunks then
      return false, self.failed_hunks[#self.failed_hunks].error
    end
  end

  -- Write file if any hunks were applied
  if self.applied_hunks > 0 then
    local success, write_err = Utils.write_file(target_file, modified_lines)
    if not success then
      return false, 'Failed to write changes to ' .. target_file .. ': ' .. (write_err or 'Unknown Error')
    end

    -- Refresh any open buffers for this file
    self:_refresh_buffer(target_file)
  end

  return self:_generate_result_message()
end

--- Reads the original file content
-- @return table|nil: Lines from the original file
function HunkMatcher:_read_original_file()
  local is_new_file = (self.parsed_diff.old_path == '/dev/null')

  if is_new_file then
    return {}
  else
    local content, err = Utils.read_file_content(self.parsed_diff.old_path)
    if not content then
      return nil
    end
    return vim.split(content, '\n', { plain = true, trimempty = false })
  end
end

--- Applies a single hunk to the modified lines
-- @param hunk The hunk to apply
-- @param hunk_idx The index of the hunk
-- @param modified_lines The lines being modified
-- @return boolean: Success status
function HunkMatcher:_apply_single_hunk(hunk, hunk_idx, modified_lines)
  local search_replace = self:_build_search_replace_patterns(hunk)

  -- Handle pure additions
  if #search_replace.search_lines == 0 and #search_replace.to_add > 0 and #search_replace.to_remove == 0 then
    return self:_apply_pure_addition(search_replace.to_add, modified_lines)
  end

  -- Try to find and apply the hunk
  local found_at, adjusted_search_lines = self:_find_hunk_location(search_replace.search_lines, modified_lines)

  if found_at > -1 then
    -- Update search_replace with adjusted search lines for fuzzy matching
    local adjusted_search_replace = vim.deepcopy(search_replace)
    adjusted_search_replace.search_lines = adjusted_search_lines

    -- For fuzzy matching, we need to rebuild replacement lines to handle additions properly
    if adjusted_search_lines ~= search_replace.search_lines then
      adjusted_search_replace.replacement_lines =
        self:_rebuild_replacement_lines_for_fuzzy_match(hunk, adjusted_search_lines, search_replace.to_add)
    end

    return self:_apply_hunk_at_location(found_at, adjusted_search_replace, modified_lines)
  else
    return self:_handle_hunk_failure(hunk_idx, hunk, search_replace.search_lines)
  end
end

--- Builds search and replacement patterns from a hunk
-- @param hunk The hunk to process
-- @return table: Search and replacement patterns
function HunkMatcher:_build_search_replace_patterns(hunk)
  local search_lines = {}
  local replacement_lines = {}
  local to_remove = {}
  local to_add = {}
  local context_before = {}
  local context_after = {}
  local in_changes = false

  -- Build search and replacement patterns correctly
  for _, line in ipairs(hunk.lines) do
    local op, text = self:_parse_hunk_line(line)

    if op == ' ' or op == '' then
      -- Context lines (including empty lines) go in both search and replacement
      table.insert(search_lines, text)
      table.insert(replacement_lines, text)
    elseif op == '-' then
      -- Removed lines only go in search pattern
      table.insert(search_lines, text)
      -- Do NOT add to replacement_lines - these should be completely removed
    elseif op == '+' then
      -- Added lines only go in replacement pattern
      table.insert(replacement_lines, text)
      -- Do NOT add to search_lines - these are new content
    end
  end

  -- Second pass: build traditional arrays for backward compatibility
  for _, line in ipairs(hunk.lines) do
    local op, text = self:_parse_hunk_line(line)

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

  return {
    search_lines = search_lines,
    replacement_lines = replacement_lines,
    to_remove = to_remove,
    to_add = to_add,
    context_before = context_before,
    context_after = context_after,
  }
end

--- Parses a single hunk line into operation and text
-- @param line The hunk line to parse
-- @return string, string: Operation character and text content
function HunkMatcher:_parse_hunk_line(line)
  local op, text

  -- Handle empty context lines correctly
  if #line == 1 and line:sub(1, 1) == ' ' then
    op = ' '
    text = ''
  elseif line:sub(1, 1) == '~' then
    -- This was a context line missing the leading space
    op = ' '
    text = line:sub(2)
  else
    op = line:sub(1, 1)
    text = line:sub(2)
  end

  return op, text
end

--- Applies a pure addition (no removals or context)
-- @param to_add Lines to add
-- @param modified_lines The lines being modified
-- @return boolean: Success status
function HunkMatcher:_apply_pure_addition(to_add, modified_lines)
  for _, line in ipairs(to_add) do
    table.insert(modified_lines, line)
  end
  self.offset = self.offset + #to_add
  self.applied_hunks = self.applied_hunks + 1
  return true
end

--- Finds the location of a hunk in the modified lines
-- @param search_lines Lines to search for
-- @param modified_lines Lines to search in
-- @return number, table: Index where hunk was found (-1 if not found) and updated search_lines
function HunkMatcher:_find_hunk_location(search_lines, modified_lines)
  -- First try exact matching
  local found_at = self:_exact_match(search_lines, modified_lines)
  if found_at > -1 then
    return found_at, search_lines
  end

  -- If exact match fails, try fuzzy matching
  return self:_fuzzy_match(search_lines, modified_lines)
end

--- Performs exact string matching
-- @param search_lines Lines to search for
-- @param modified_lines Lines to search in
-- @return number: Index where found (-1 if not found)
function HunkMatcher:_exact_match(search_lines, modified_lines)
  for i = 1, #modified_lines - #search_lines + 1 do
    local match = true
    for j = 1, #search_lines do
      if modified_lines[i + j - 1] ~= search_lines[j] then
        match = false
        break
      end
    end
    if match then
      return i
    end
  end
  return -1
end

--- Performs fuzzy matching that skips blank lines
-- @param search_lines Lines to search for
-- @param modified_lines Lines to search in
-- @return number, table: Index where found (-1 if not found) and updated search_lines
function HunkMatcher:_fuzzy_match(search_lines, modified_lines)
  -- Create non-blank line patterns for fuzzy matching
  local search_non_blank = {}
  for _, line in ipairs(search_lines) do
    if line ~= '' then
      table.insert(search_non_blank, line)
    end
  end

  -- Only try fuzzy matching if we have non-blank lines to match
  if #search_non_blank == 0 then
    return -1, search_lines
  end

  for start_pos = 1, #modified_lines do
    local match_result = self:_try_fuzzy_match_at_position(search_non_blank, modified_lines, start_pos, search_lines)
    if match_result.found then
      return match_result.position, match_result.adjusted_search_lines
    end
  end

  return -1, search_lines
end

--- Tries fuzzy matching at a specific position
-- @param search_non_blank Non-blank search lines
-- @param modified_lines Lines to search in
-- @param start_pos Starting position
-- @param original_search_lines Original search lines for length calculation
-- @return table: Match result with found status, position, and adjusted search lines
function HunkMatcher:_try_fuzzy_match_at_position(search_non_blank, modified_lines, start_pos, original_search_lines)
  local file_non_blank = {}
  local end_pos = start_pos

  -- Collect non-blank lines from file starting at start_pos
  for i = start_pos, #modified_lines do
    if modified_lines[i] ~= '' then
      table.insert(file_non_blank, modified_lines[i])
      if #file_non_blank == #search_non_blank then
        end_pos = i
        break
      end
    end
    -- Stop if we've gone too far without finding enough non-blank lines
    if i - start_pos > #original_search_lines + 10 then
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
      -- Build adjusted search lines to match the actual span we found
      local adjusted_search_lines = {}
      for i = start_pos, end_pos do
        table.insert(adjusted_search_lines, modified_lines[i])
      end
      return { found = true, position = start_pos, adjusted_search_lines = adjusted_search_lines }
    end
  end

  return { found = false }
end

--- Rebuilds replacement lines for fuzzy matching scenarios
-- @param hunk The original hunk
-- @param adjusted_search_lines The adjusted search lines from fuzzy matching
-- @param to_add Lines to add from the hunk
-- @return table: The rebuilt replacement lines
function HunkMatcher:_rebuild_replacement_lines_for_fuzzy_match(hunk, adjusted_search_lines, to_add)
  local replacement_lines = {}

  -- For fuzzy matching, we need to properly interleave additions with the context
  -- We'll process the hunk line by line, keeping track of what to include
  local addition_lines = {}
  local current_pos = 1

  -- First build a map of where additions should go
  for i, hunk_line in ipairs(hunk.lines) do
    local op, text = self:_parse_hunk_line(hunk_line)
    if op == '+' then
      table.insert(addition_lines, { position = current_pos, text = text })
    elseif op == ' ' or op == '-' then
      current_pos = current_pos + 1
    end
  end

  -- Simple approach: rebuild replacement pattern by processing hunk sequentially
  for i, hunk_line in ipairs(hunk.lines) do
    local op, text = self:_parse_hunk_line(hunk_line)

    if op == ' ' or op == '' then
      -- Context lines (including empty lines): always include in replacement
      table.insert(replacement_lines, text)
    elseif op == '+' then
      -- Addition line: include in replacement
      table.insert(replacement_lines, text)
      -- Skip op == '-' lines - these should not be in replacement
    end
  end

  return replacement_lines
end

--- Applies a hunk at a specific location
-- @param found_at Location where hunk was found
-- @param search_replace Search and replacement patterns
-- @param modified_lines Lines being modified
-- @return boolean: Success status
function HunkMatcher:_apply_hunk_at_location(found_at, search_replace, modified_lines)
  -- Remove the old lines
  for _ = 1, #search_replace.search_lines do
    table.remove(modified_lines, found_at)
  end

  -- Insert the new lines
  for i, line in ipairs(search_replace.replacement_lines) do
    table.insert(modified_lines, found_at + i - 1, line)
  end

  self.offset = self.offset + (#search_replace.replacement_lines - #search_replace.search_lines)
  self.applied_hunks = self.applied_hunks + 1
  return true
end

--- Handles hunk application failure
-- @param hunk_idx Index of the failed hunk
-- @param hunk The failed hunk
-- @param search_lines Lines that couldn't be found
-- @return boolean: Always false
function HunkMatcher:_handle_hunk_failure(hunk_idx, hunk, search_lines)
  local target_file = self.parsed_diff.new_path
  local error_msg = 'Failed to apply hunk #' .. hunk_idx .. ' to ' .. target_file .. '.\n'
  error_msg = error_msg .. 'Hunk content:\n' .. table.concat(hunk.lines, '\n') .. '\n\n'
  error_msg = error_msg .. 'Searching for pattern:\n' .. table.concat(search_lines, '\n') .. '\n\n'
  error_msg = error_msg .. 'Could not find this context in the file.'

  table.insert(self.failed_hunks, { index = hunk_idx, error = error_msg })
  return false
end

--- Refreshes any open buffer for the target file
-- @param filepath The file path to refresh
function HunkMatcher:_refresh_buffer(filepath)
  -- Get the absolute path to ensure proper matching
  local abs_filepath = vim.fn.fnamemodify(filepath, ':p')

  -- Find all buffers that match this file
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf_id) and vim.api.nvim_buf_is_loaded(buf_id) then
      local buf_name = vim.api.nvim_buf_get_name(buf_id)
      if buf_name ~= '' then
        local abs_buf_name = vim.fn.fnamemodify(buf_name, ':p')
        if abs_buf_name == abs_filepath then
          self:_handle_buffer_refresh(buf_id, filepath)
        end
      end
    end
  end
end

--- Handles refreshing a specific buffer
-- @param buf_id The buffer ID to refresh
-- @param filepath The file path being refreshed
function HunkMatcher:_handle_buffer_refresh(buf_id, filepath)
  local modified = vim.bo[buf_id].modified
  if modified then
    -- Ask user what to do with modified buffer
    local choice = vim.fn.confirm(
      'Buffer for "' .. vim.fn.fnamemodify(filepath, ':t') .. '" has unsaved changes.\nReload with patch changes?',
      '&Reload\n&Keep current\n&Cancel',
      1
    )
    if choice == 1 then -- Reload
      vim.api.nvim_buf_call(buf_id, function()
        vim.cmd 'edit!'
      end)
      vim.notify('[Vibe] Reloaded buffer: ' .. vim.fn.fnamemodify(filepath, ':t'), vim.log.levels.INFO)
    elseif choice == 2 then -- Keep current
      vim.notify('[Vibe] Kept current buffer changes: ' .. vim.fn.fnamemodify(filepath, ':t'), vim.log.levels.INFO)
    end
  else
    -- Buffer is not modified, safe to reload
    vim.api.nvim_buf_call(buf_id, function()
      vim.cmd 'edit!'
    end)
    vim.notify('[Vibe] Refreshed buffer: ' .. vim.fn.fnamemodify(filepath, ':t'), vim.log.levels.INFO)
  end
end

--- Generates the final result message
-- @return boolean, string: Success status and message
function HunkMatcher:_generate_result_message()
  local target_file = self.parsed_diff.new_path
  local total_hunks = #self.parsed_diff.hunks
  local failed_count = #self.failed_hunks

  if failed_count == 0 then
    return true, 'Successfully applied ' .. total_hunks .. ' hunks to ' .. target_file
  elseif self.applied_hunks > 0 then
    local success_msg =
      string.format('Partially applied %d/%d hunks to %s', self.applied_hunks, total_hunks, target_file)
    if self.split_hunks then
      success_msg = success_msg
        .. '\nFailed hunks: '
        .. table.concat(
          vim.tbl_map(function(f)
            return '#' .. f.index
          end, self.failed_hunks),
          ', '
        )
    end
    return true, success_msg
  else
    -- All hunks failed
    local error_msg = 'Failed to apply any hunks to ' .. target_file
    if #self.failed_hunks > 0 then
      error_msg = error_msg .. '\nFirst error: ' .. self.failed_hunks[1].error
    end
    return false, error_msg
  end
end

--- Compares two line arrays for equality
-- @param lines1 First array of lines
-- @param lines2 Second array of lines
-- @return boolean: True if arrays are identical
function HunkMatcher:_compare_line_arrays(lines1, lines2)
  if #lines1 ~= #lines2 then
    return false
  end

  for i = 1, #lines1 do
    if lines1[i] ~= lines2[i] then
      return false
    end
  end

  return true
end

--- Validates that modified content has reasonable structure
-- @param lines Array of lines to validate
-- @return boolean: True if content appears valid
function HunkMatcher:_validate_modified_content(lines)
  -- Check for basic sanity - no embedded line numbers or weird artifacts
  for _, line in ipairs(lines) do
    -- Look for patterns that indicate corruption
    if
      line:match '%d+→' -- Line number artifacts like "123→"
      or line:match 'No newline at end of file' -- Git artifacts
      or line:match '^%s*%.%.%.%s*$'
    then -- Random ellipsis lines
      return false
    end
  end

  return true
end

return HunkMatcher
