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
      fixed_line, fix = Validation._process_old_file_header(line, i)
      if fix then
        table.insert(fixes, fix)
      end
    elseif line_count <= 3 and line:match '^%+%+%+%s' and not in_hunk then
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

    if PathUtils.looks_like_file(file_path) then
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

    -- Check for diff headers
    if line:match '^---' or line:match '^%+%+%+' then
      has_header = true
      fixed_line, issue = Validation._fix_header_line(line, i)
      if issue then
        table.insert(issues, issue)
      end
    -- Check for hunk headers
    elseif line:match '^@@' then
      in_hunk = true
      fixed_line, issue = Validation._fix_hunk_header(line, i)
      if issue then
        table.insert(issues, issue)
      end
    -- Check context and change lines
    elseif in_hunk then
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
  local op = line:sub(1, 1)

  if op == ' ' or op == '' then
    -- Context line - fix missing space prefix
    if op == '' and line ~= '' then
      return ' ' .. line,
        {
          line = line_num,
          type = 'context',
          message = 'Added missing space prefix for context line',
        }
    end
  elseif op == '-' or op == '+' then
    -- Valid change line
    return line, nil
  else
    -- Invalid line in hunk
    if line ~= '' then
      return line,
        {
          line = line_num,
          type = 'invalid_line',
          message = 'Invalid line in hunk: ' .. line,
          severity = 'warning',
        }
    end
  end
  return line, nil
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

return Validation
