-- vibe-coding/validation.lua
-- Consolidated validation pipeline for diff processing

local PathUtils = require 'vibe-coding.path_utils'

local Validation = {}

--- Validates and fixes a diff through the complete pipeline
-- @param diff_content The raw diff content
-- @return string, table: The processed diff content and issues found
function Validation.process_diff(diff_content)
  local pipeline = {
    Validation.fix_file_paths,
    Validation.smart_validate_against_original,
    Validation.validate_and_fix_diff,
    Validation.format_diff,
  }

  local current_content = diff_content
  local all_issues = {}

  for _, step in ipairs(pipeline) do
    local result, issues = step(current_content)
    current_content = result

    -- Merge issues from this step
    if issues then
      for _, issue in ipairs(issues) do
        table.insert(all_issues, issue)
      end
    end
  end

  return current_content, all_issues
end

--- Intelligently resolves file paths in diff headers by searching the filesystem.
-- @param diff_content The diff content to fix.
-- @return string, table: The fixed diff content and a table of fixes applied.
function Validation.fix_file_paths(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local fixed_lines = {}
  local fixes = {}

  local in_hunk = false
  local line_count = 0

  for i, line in ipairs(lines) do
    local fixed_line = line
    line_count = line_count + 1

    -- Track if we're in a hunk to avoid processing hunk content as headers
    if line:match '^@@' then
      in_hunk = true
    elseif line_count <= 2 and line:match '^---%s' and not in_hunk then
      local fix
      fixed_line, fix = Validation._process_old_file_header(line, i)
      if fix then
        table.insert(fixes, fix)
      end
    elseif line_count <= 3 and line:match '^%+%+%+%s' and not in_hunk then
      local fix
      fixed_line, fix = Validation._process_new_file_header(line, i)
      if fix then
        table.insert(fixes, fix)
      end
    end

    table.insert(fixed_lines, fixed_line)
  end

  return table.concat(fixed_lines, '\n'), fixes
end

--- Processes old file header (--- line)
-- @param line The line to process
-- @param line_num The line number
-- @return string, table|nil: Fixed line and optional fix info
function Validation._process_old_file_header(line, line_num)
  local file_path = line:match '^---%s+(.*)$'
  if file_path and file_path ~= '' and file_path ~= '/dev/null' then
    file_path = PathUtils.clean_path(file_path)

    if file_path and PathUtils.looks_like_file(file_path) then
      -- Check if it's already a valid absolute path
      if file_path:match '^/' and vim.fn.filereadable(file_path) == 1 then
        -- Valid absolute path - no issue to report
        return line, nil
      end

      local resolved_path = PathUtils.resolve_file_path(file_path)
      if resolved_path and resolved_path ~= file_path then
        return '--- ' .. resolved_path,
          {
            line = line_num,
            type = 'path_resolution',
            message = string.format('Resolved file path: %s → %s', file_path, resolved_path),
          }
      elseif not resolved_path then
        return line,
          {
            line = line_num,
            type = 'path_not_found',
            message = string.format('Could not locate file: %s (you may need to fix this manually)', file_path),
            severity = 'warning',
          }
      end
    end
  end
  return line, nil
end

--- Processes new file header (+++ line)
-- @param line The line to process
-- @param line_num The line number
-- @return string, table|nil: Fixed line and optional fix info
function Validation._process_new_file_header(line, line_num)
  local file_path = line:match '^%+%+%+%s+(.*)$'
  if file_path and file_path ~= '' and file_path ~= '/dev/null' then
    if PathUtils.looks_like_file(file_path) then
      -- Check if it's already a valid absolute path
      if file_path:match '^/' and vim.fn.filereadable(file_path) == 1 then
        -- Valid absolute path - no issue to report
        return line, nil
      end

      local resolved_path = PathUtils.resolve_file_path(file_path)
      if resolved_path and resolved_path ~= file_path then
        return '+++ ' .. resolved_path,
          {
            line = line_num,
            type = 'path_resolution',
            message = string.format('Resolved file path: %s → %s', file_path, resolved_path),
          }
      elseif not resolved_path then
        return line,
          {
            line = line_num,
            type = 'path_not_found',
            message = string.format('Could not locate file: %s (you may need to fix this manually)', file_path),
            severity = 'warning',
          }
      end
    end
  end
  return line, nil
end

--- Validates and fixes common issues in diff content.
-- @param diff_content The raw diff content to validate.
-- @return string, table: The cleaned diff content and a table of issues found.
function Validation.validate_and_fix_diff(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local issues = {}
  local fixed_lines = {}

  -- Track state for validation
  local has_header = false
  local in_hunk = false

  for i, line in ipairs(lines) do
    local fixed_line = line

    -- Check for diff headers (but not when inside a hunk)
    if not in_hunk and (line:match '^---' or line:match '^%+%+%+') then
      has_header = true
      local issue
      fixed_line, issue = Validation._fix_header_line(line, i)
      if issue then
        table.insert(issues, issue)
      end
    -- Check for hunk headers
    elseif line:match '^@@' then
      in_hunk = true
      local issue
      fixed_line, issue = Validation._fix_hunk_header(line, i)
      if issue then
        table.insert(issues, issue)
      end
    -- Check context and change lines
    elseif in_hunk then
      local issue
      fixed_line, issue = Validation._fix_hunk_content_line(line, i)
      if issue then
        table.insert(issues, issue)
      end
    end

    table.insert(fixed_lines, fixed_line)
  end

  -- Final validation
  if not has_header then
    table.insert(issues, {
      line = 1,
      type = 'missing_header',
      message = 'Diff missing file headers',
      severity = 'error',
    })
  end

  return table.concat(fixed_lines, '\n'), issues
end

--- Fixes header line issues
-- @param line The line to fix
-- @param line_num The line number
-- @return string, table|nil: Fixed line and optional issue
function Validation._fix_header_line(line, line_num)
  if line:match '^---%s*$' then
    return '--- /dev/null',
      {
        line = line_num,
        type = 'header',
        message = 'Fixed empty old file header',
      }
  elseif line:match '^%+%+%+%s*$' then
    return '+++ /dev/null',
      {
        line = line_num,
        type = 'header',
        message = 'Fixed empty new file header',
      }
  end
  return line, nil
end

--- Fixes hunk header issues
-- @param line The line to fix
-- @param line_num The line number
-- @return string, table|nil: Fixed line and optional issue
function Validation._fix_hunk_header(line, line_num)
  local old_start, _, new_start, _ = line:match '^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@'

  if not old_start then
    -- Try simpler format without counts
    old_start, new_start = line:match '^@@ %-(%d+) %+(%d+) @@'
    if old_start then
      return string.format('@@ -%s,1 +%s,1 @@', old_start, new_start),
        {
          line = line_num,
          type = 'hunk_header',
          message = 'Added missing line counts',
        }
    else
      -- Check for malformed headers
      if line:match '^@@ ' then
        return '@@ -1,1 +1,1 @@',
          {
            line = line_num,
            type = 'hunk_header',
            message = 'Normalized malformed hunk header (line numbers ignored for search-and-replace)',
            severity = 'info',
          }
      else
        return line,
          {
            line = line_num,
            type = 'hunk_header',
            message = 'Invalid hunk header format',
            severity = 'error',
          }
      end
    end
  end
  return line, nil
end

--- Fixes hunk content line issues
-- @param line The line to fix
-- @param line_num The line number
-- @return string, table|nil: Fixed line and optional issue
function Validation._fix_hunk_content_line(line, line_num)
  -- Handle empty lines - they're valid as-is
  if line == '' then
    return line, nil
  end

  local op = line:sub(1, 1)

  -- Handle valid diff operators
  if op == ' ' or op == '-' or op == '+' then
    return line, nil
  end

  -- Try to intelligently fix context lines missing the leading space
  -- This is common with LLM-generated diffs where the space prefix is omitted
  local fixed_line, issue = Validation._try_fix_missing_context_prefix(line, line_num)
  if fixed_line then
    return fixed_line, issue
  end

  -- If we can't fix it, report as invalid
  return line,
    {
      line = line_num,
      type = 'invalid_line',
      message = 'Invalid line in hunk: ' .. line,
      severity = 'warning',
    }
end

--- Attempts to fix a line that's missing the context prefix space
-- @param line The line to potentially fix
-- @param line_num The line number
-- @return string|nil, table|nil: Fixed line and issue, or nil if can't fix
function Validation._try_fix_missing_context_prefix(line, line_num)
  -- Generic approach: if line is not empty and doesn't start with +/-, treat as context
  if line ~= '' and not line:match '^[+-]' then
    return ' ' .. line,
      {
        line = line_num,
        type = 'context_fix',
        message = 'Added missing space prefix for context line: '
          .. (line:sub(1, 50) .. (line:len() > 50 and '...' or '')),
        severity = 'info',
      }
  end

  return nil, nil
end

--- Formats diff content for better readability and standards compliance.
-- @param diff_content The diff content to format.
-- @return string, table: The formatted diff content and empty issues table.
function Validation.format_diff(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local formatted_lines = {}

  local in_hunk = false
  local line_count = 0

  for _, line in ipairs(lines) do
    line_count = line_count + 1

    -- Track if we're in a hunk to avoid processing hunk content as headers
    if line:match '^@@' then
      in_hunk = true
      table.insert(formatted_lines, line)
    elseif line_count <= 2 and line:match '^---' and not in_hunk then
      table.insert(formatted_lines, Validation._format_old_header(line))
    elseif line_count <= 3 and line:match '^%+%+%+' and not in_hunk then
      table.insert(formatted_lines, Validation._format_new_header(line))
    else
      -- For all other lines, pass through as-is
      table.insert(formatted_lines, line)
    end
  end

  return table.concat(formatted_lines, '\n'), {}
end

--- Formats old file header
-- @param line The line to format
-- @return string: The formatted line
function Validation._format_old_header(line)
  local file_path = line:match '^---%s*(.*)$'
  if file_path and file_path ~= '' then
    file_path = PathUtils.clean_path(file_path)
    if file_path ~= '' then
      return '--- ' .. file_path
    end
  end
  return '--- /dev/null'
end

--- Formats new file header
-- @param line The line to format
-- @return string: The formatted line
function Validation._format_new_header(line)
  local file_path = line:match '^%+%+%+%s*(.*)$'
  if file_path and file_path ~= '' then
    return '+++ ' .. file_path
  end
  return '+++ /dev/null'
end

--- Creates a standardized error result
-- @param message The error message
-- @param severity The error severity
-- @return table: Standardized error object
function Validation.create_error(message, severity)
  return {
    success = false,
    message = message,
    severity = severity or 'error',
    timestamp = os.time(),
  }
end

--- Creates a standardized success result
-- @param message The success message
-- @param data Optional data to include
-- @return table: Standardized success object
function Validation.create_success(message, data)
  return {
    success = true,
    message = message,
    data = data,
    timestamp = os.time(),
  }
end

--- Smart validation that compares diff context with original file content
-- @param diff_content The diff content to validate
-- @return string, table: The fixed diff content and issues found
function Validation.smart_validate_against_original(diff_content)
  local lines = vim.split(diff_content, '\n', { plain = true })
  local issues = {}
  local fixed_lines = {}

  local current_file = nil
  local original_lines = nil

  for i, line in ipairs(lines) do
    local process_result = Validation._process_line_for_smart_validation(line, i, current_file, original_lines, issues)

    -- Update current file tracking
    if process_result.current_file then
      current_file = process_result.current_file
      original_lines = process_result.original_lines
    end

    -- Add the fixed line(s) to output
    for _, fixed_line in ipairs(process_result.fixed_lines) do
      table.insert(fixed_lines, fixed_line)
    end
  end

  return table.concat(fixed_lines, '\n'), issues
end

--- Processes a single line for smart validation
-- @param line The line to process
-- @param line_num The line number
-- @param current_file Current file being tracked
-- @param original_lines Original file lines if available
-- @param issues Issues table to append to
-- @return table: Result with fixed_lines, current_file, original_lines
function Validation._process_line_for_smart_validation(line, line_num, current_file, original_lines, issues)
  local result = {
    fixed_lines = { line },
    current_file = nil,
    original_lines = nil,
  }

  -- Suppress unused parameter warning
  _ = current_file

  -- Track current file being processed (only process actual file headers, not diff content)
  if line:match '^---' then
    local file_path = line:match '^---%s+(.*)$'
    if file_path and file_path ~= '/dev/null' and PathUtils.looks_like_file(file_path) then
      -- Clean up the file path
      file_path = PathUtils.clean_path(file_path)

      -- Resolve the file path using the intelligent search system
      local resolved_path = PathUtils.resolve_file_path(file_path)
      result.current_file = resolved_path or file_path

      -- Try to read the original file using the resolved path
      local final_path = resolved_path or file_path
      if final_path then
        local content, _ = require('vibe-coding.utils').read_file_content(final_path)
        if content then
          result.original_lines = vim.split(content, '\n', { plain = true, trimempty = false })
        else
          -- Add diagnostic information about why file couldn't be read
          -- Only report this for actual file paths, not code content
          if PathUtils.looks_like_file(final_path) then
            table.insert(issues, {
              line = line_num,
              type = 'file_access',
              message = string.format(
                'Could not read original file: %s (resolved from: %s)',
                final_path,
                file_path or 'unknown'
              ),
              severity = 'info',
            })
          end
        end
      end
    end
    return result
  end

  -- Handle hunk headers with missing line breaks
  if line:match '^@@' then
    local hunk_header, content_after = line:match '^(@@ %-?%d+,?%d* %+?%d+,?%d* @@)(.+)'
    if hunk_header and content_after and content_after ~= '' then
      -- Split the line: return hunk header and process content separately
      result.fixed_lines = { hunk_header }

      table.insert(issues, {
        line = line_num,
        type = 'hunk_header',
        message = 'Split hunk header from content (missing line break)',
        severity = 'warning',
      })

      -- Process the content after as a context line if we have original file
      if original_lines then
        local content_result = Validation._process_context_line(content_after, line_num, original_lines, issues, false)
        -- Add the processed content lines
        for _, content_line in ipairs(content_result.fixed_lines) do
          table.insert(result.fixed_lines, content_line)
        end
      else
        -- No original file available, just add basic context prefix
        table.insert(result.fixed_lines, ' ' .. content_after)
        table.insert(issues, {
          line = line_num,
          type = 'context_fix',
          message = 'Added missing space prefix for context line (original file not found): ' .. content_after,
          severity = 'warning',
        })
      end

      return result
    end
  end

  -- Process context lines in hunks (both properly formatted and missing space prefix)
  if line:match '^%s' and original_lines then
    return Validation._process_context_line(line, line_num, original_lines, issues, true)
  end

  -- Also check lines that should be context but are missing the space prefix
  if
    original_lines
    and not line:match '^[+@-]'
    and not line:match '^%+%+%+'
    and not line:match '^---'
    and line ~= ''
  then
    return Validation._process_context_line(line, line_num, original_lines, issues, false)
  end

  return result
end

--- Processes a context line for smart validation
-- @param line The line to process
-- @param line_num The line number
-- @param original_lines Original file lines
-- @param issues Issues table to append to
-- @param has_space_prefix Whether the line already has a space prefix
-- @return table: Result with fixed_lines array
function Validation._process_context_line(line, line_num, original_lines, issues, has_space_prefix)
  local result = { fixed_lines = {} }
  local context_text = has_space_prefix and line:sub(2) or line
  local issue = Validation._validate_context_against_original(context_text, original_lines, line_num)

  if not issue then
    table.insert(result.fixed_lines, line)
    return result
  end

  table.insert(issues, issue)

  -- Handle generic joined lines formatting issue
  if issue.type == 'formatting_issue' and issue.split_lines then
    -- Replace the current line with the split lines
    issue.message = issue.message .. ' (auto-corrected: split into ' .. #issue.split_lines .. ' lines)'
    issue.severity = 'info'

    -- The split_lines from _find_prefix_match already have correct indentation from original file
    -- Just add space prefix for diff format
    for _, split_line in ipairs(issue.split_lines) do
      table.insert(result.fixed_lines, ' ' .. split_line)
    end
    return result
  end

  -- Try to fix other formatting issues
  local corrected_line = Validation._fix_context_line_formatting(context_text, original_lines)
  if corrected_line then
    local fixed_line = ' ' .. corrected_line
    issue.message = issue.message .. ' (auto-corrected)'
    issue.severity = 'info'
    table.insert(result.fixed_lines, fixed_line)
    return result
  end

  -- Final fallback
  if has_space_prefix then
    table.insert(result.fixed_lines, line)
  else
    local fixed_line = ' ' .. line
    issue.message = issue.message .. ' (added space prefix)'
    issue.severity = 'warning'
    table.insert(result.fixed_lines, fixed_line)
  end

  return result
end

--- Validates a context line against the original file content
-- @param context_text The text from the context line (without leading space)
-- @param original_lines Array of lines from the original file
-- @param line_num Line number for error reporting
-- @return table|nil: Issue object if validation fails
function Validation._validate_context_against_original(context_text, original_lines, line_num)
  -- Skip empty lines
  if context_text == '' then
    return nil
  end

  -- Check if this exact line exists in the original file
  for _, orig_line in ipairs(original_lines) do
    if orig_line == context_text then
      return nil -- Found exact match, all good
    end
  end

  -- No exact match found, this might be a formatting issue
  -- Common issues: joined lines, missing indentation, etc.

  -- Check if context_text is a prefix of any original line
  -- This handles common cases where multiple lines are joined together
  local prefix_match = Validation._find_prefix_match(context_text, original_lines)
  if prefix_match then
    local message
    message = 'Joined line detected (prefix match): '
      .. context_text:sub(1, 60)
      .. (context_text:len() > 60 and '...' or '')

    return {
      line = line_num,
      type = 'formatting_issue',
      message = message,
      severity = 'warning',
      original_text = context_text,
      split_lines = prefix_match,
    }
  end

  -- Generic case: line not found in original
  return {
    line = line_num,
    type = 'context_mismatch',
    message = 'Context line not found in original file: '
      .. context_text:sub(1, 50)
      .. (context_text:len() > 50 and '...' or ''),
    severity = 'warning',
    original_text = context_text,
  }
end

--- Attempts to fix formatting issues in context lines
-- @param context_text The problematic context text
-- @param original_lines Array of lines from the original file
-- @return string|nil: Fixed text or nil if can't fix
function Validation._fix_context_line_formatting(context_text, original_lines)
  -- Generic approach: look for any line that contains the first few words
  local context_words = {}
  for word in context_text:gmatch '%S+' do
    table.insert(context_words, word)
  end

  if #context_words > 0 then
    -- Find lines that contain the first few words
    local search_pattern = vim.pesc(context_words[1])
    if context_words[2] then
      search_pattern = search_pattern .. '.*' .. vim.pesc(context_words[2])
    end

    for _, orig_line in ipairs(original_lines) do
      if orig_line:match(search_pattern) then
        -- Found a similar line, use it as the correction
        return orig_line
      end
    end
  end

  return nil -- Can't fix automatically
end

--- Finds if context_text is a prefix of lines in the original file and extracts the split
-- @param context_text The potentially joined line
-- @param original_lines Array of lines from the original file
-- @return table|nil: Array of split lines that reconstruct the context_text, or nil if no match
function Validation._find_prefix_match(context_text, original_lines)
  if not original_lines or #original_lines == 0 or context_text == '' then
    return nil
  end

  -- Remove leading/trailing whitespace for comparison
  local trimmed_context = context_text:gsub('^%s+', ''):gsub('%s+$', '')

  -- Try to find a sequence of original lines that when concatenated (with appropriate separators)
  -- would create the context_text
  for start_idx = 1, #original_lines do
    local matched_lines = {}

    -- Try building up the context_text from consecutive original lines
    for end_idx = start_idx, math.min(start_idx + 4, #original_lines) do -- Limit to 5 lines max
      local orig_line = original_lines[end_idx]
      local trimmed_orig = orig_line:gsub('^%s+', ''):gsub('%s+$', '')

      if trimmed_orig == '' then
        break -- Skip empty lines for now
      end

      table.insert(matched_lines, orig_line)

      -- Generic join strategy: try direct concatenation of trimmed lines
      local joined = ''
      for i, line in ipairs(matched_lines) do
        local line_trimmed = line:gsub('^%s+', ''):gsub('%s+$', '')
        if i == 1 then
          joined = line_trimmed
        else
          joined = joined .. line_trimmed
        end
      end

      -- Check if this matches our context text
      if joined == trimmed_context then
        return matched_lines
      end

      -- Only check for very specific joining patterns to avoid false positives
      -- (Removed the aggressive prefix matching that was splitting legitimate lines)
    end
  end

  return nil
end

--- Validates if a split candidate matches lines in the original file
-- @param candidate Array of split line candidates
-- @param original_lines Array of original file lines
-- @return boolean: True if the split lines can be found in original
function Validation._validate_split_against_original(candidate, original_lines)
  -- Check if all parts of the candidate can be found in the original file
  local found_count = 0

  for _, split_line in ipairs(candidate) do
    local trimmed = split_line:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed ~= '' then
      for _, orig_line in ipairs(original_lines) do
        local orig_trimmed = orig_line:gsub('^%s+', ''):gsub('%s+$', '')
        if orig_trimmed == trimmed or orig_line:find(trimmed, 1, true) then
          found_count = found_count + 1
          break
        end
      end
    end
  end

  -- Require that at least 80% of split lines match original content
  return found_count >= math.max(1, math.floor(#candidate * 0.8))
end

--- Corrects the indentation of a split line by finding the correct version in the original file
-- @param split_line The line after splitting
-- @param original_lines Array of original file lines
-- @param is_continuation_line Whether this is a continuation line (like docstring after function)
-- @return string: Line with correct indentation
function Validation._correct_line_indentation(split_line, original_lines, is_continuation_line)
  if not original_lines then
    return split_line
  end

  local trimmed_split = split_line:gsub('^%s+', ''):gsub('%s+$', '')

  -- Look for exact content match in original to get proper indentation
  for _, orig_line in ipairs(original_lines) do
    local trimmed_orig = orig_line:gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed_orig == trimmed_split then
      return orig_line -- Use original with proper indentation
    end

    -- For docstrings, also check if the content matches (ignoring whitespace)
    if trimmed_split:match '^""".*"""$' and trimmed_orig:match '^""".*"""$' then
      local split_content = trimmed_split:match '^"""(.*)"""$'
      local orig_content = trimmed_orig:match '^"""(.*)"""$'
      if split_content == orig_content then
        return orig_line -- Use original with proper indentation
      end
    end
  end

  -- If not found and it's a continuation line, try to infer proper indentation
  if is_continuation_line and trimmed_split:match '^"""' then
    -- For docstrings, typically indent 4 spaces relative to function
    return '    ' .. trimmed_split
  end

  return split_line -- Fallback to as-is
end

return Validation
