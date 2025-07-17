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

    if PathUtils.looks_like_file(file_path) then
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

    -- Check for diff headers
    if line:match '^---' or line:match '^%+%+%+' then
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
  -- Don't try to fix lines that start with special characters that might be intentional
  local first_char = line:sub(1, 1)

  -- Skip lines that start with characters that are unlikely to be context lines
  if first_char:match '[#@\\/%*]' then
    return nil, nil
  end

  -- Skip lines that look like they might be meant as additions/removals
  -- (though this is harder to detect definitively)
  if line:match '^%s*[+-]' then
    return nil, nil
  end

  -- Check if this looks like a valid code/text line that should be context
  -- Most context lines in code diffs will be:
  -- 1. Indented code (spaces/tabs)
  -- 2. Function definitions
  -- 3. Comments
  -- 4. Normal text content
  local looks_like_context = (
    line:match '^%s+' -- Starts with whitespace (indented code)
    or line:match '^[%a_]' -- Starts with letter/underscore (function names, variables)
    or line:match '^["\']' -- Starts with quote (strings)
    or line:match '^[}%)]' -- Starts with closing bracket/paren
    or line:match '^[{%(]' -- Starts with opening bracket/paren
    or line:match '^%w' -- Starts with word character
  )

  if looks_like_context then
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
  local original_content = nil
  local original_lines = nil
  
  for i, line in ipairs(lines) do
    local fixed_line = line
    
    -- Track current file being processed
    if line:match('^---') then
      local file_path = line:match('^---%s+(.*)$')
      if file_path and file_path ~= '/dev/null' then
        -- Clean up the file path
        file_path = PathUtils.clean_path(file_path)
        current_file = file_path
        
        -- Try to read the original file
        if vim.fn.filereadable(current_file) == 1 then
          local content, _ = require('vibe-coding.utils').read_file_content(current_file)
          if content then
            original_content = content
            original_lines = vim.split(content, '\n', { plain = true, trimempty = false })
          end
        end
      end
    -- Process context lines in hunks (both properly formatted and missing space prefix)
    elseif line:match('^%s') and original_lines then
      -- This is a properly formatted context line, validate it against original
      local context_text = line:sub(2) -- Remove leading space
      local issue = Validation._validate_context_against_original(context_text, original_lines, i)
      if issue then
        table.insert(issues, issue)
        -- Special handling for function definition joined with docstring  
        if issue.type == 'formatting_issue' and issue.message:match('Function definition joined with docstring') then
          local corrected_lines = Validation._fix_joined_function_docstring(context_text, original_lines)
          if corrected_lines then
            -- Replace the current line with the fixed function definition
            fixed_line = ' ' .. corrected_lines[1]
            issue.message = issue.message .. ' (auto-corrected: separated function and docstring)'
            issue.severity = 'info'
            
            -- Insert the docstring line after this one
            if corrected_lines[2] then
              table.insert(fixed_lines, fixed_line)
              table.insert(fixed_lines, ' ' .. corrected_lines[2])
              -- Continue to next iteration since we've added both lines
              goto continue_loop
            end
          else
            -- Try to fix the issue with original logic
            local corrected_line = Validation._fix_context_line_formatting(context_text, original_lines)
            if corrected_line then
              fixed_line = ' ' .. corrected_line
              issue.message = issue.message .. ' (auto-corrected)'
              issue.severity = 'info'
            end
          end
        else
          -- Try to fix the issue
          local corrected_line = Validation._fix_context_line_formatting(context_text, original_lines)
          if corrected_line then
            fixed_line = ' ' .. corrected_line
            issue.message = issue.message .. ' (auto-corrected)'
            issue.severity = 'info'
          end
        end
      end
    -- Also check lines that should be context but are missing the space prefix
    elseif original_lines and not line:match('^[+@-]') and not line:match('^%+%+%+') and not line:match('^---') and line ~= '' then
      -- This might be a context line missing the space prefix - check if it looks like context
      local issue = Validation._validate_context_against_original(line, original_lines, i)
      if issue then
        table.insert(issues, issue)
        -- Special handling for function definition joined with docstring
        if issue.type == 'formatting_issue' and issue.message:match('Function definition joined with docstring') then
          local corrected_lines = Validation._fix_joined_function_docstring(line, original_lines)
          if corrected_lines then
            -- Replace the current line with the fixed function definition
            fixed_line = ' ' .. corrected_lines[1]
            issue.message = issue.message .. ' (auto-corrected: separated function and docstring)'
            issue.severity = 'info'
            
            -- Insert the docstring line after this one
            if corrected_lines[2] then
              table.insert(fixed_lines, fixed_line)
              table.insert(fixed_lines, ' ' .. corrected_lines[2])
              -- Continue to next iteration since we've added both lines
              goto continue_loop
            end
          else
            -- If we can't fix the specific formatting issue, just add space prefix
            fixed_line = ' ' .. line
            issue.message = issue.message .. ' (added space prefix, manual fix needed)'
            issue.severity = 'warning'
          end
        else
          -- Try to fix other formatting issues
          local corrected_line = Validation._fix_context_line_formatting(line, original_lines)
          if corrected_line then
            fixed_line = ' ' .. corrected_line
            issue.message = issue.message .. ' (auto-corrected)'
            issue.severity = 'info'
          else
            -- If we can't fix the formatting, at least add the space prefix
            fixed_line = ' ' .. line
            issue.message = issue.message .. ' (added space prefix)'
            issue.severity = 'warning'
          end
        end
      end
    end
    
    table.insert(fixed_lines, fixed_line)
    ::continue_loop::
  end
  
  return table.concat(fixed_lines, '\n'), issues
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
  
  -- Check for common patterns that suggest formatting issues
  local patterns_to_check = {
    -- Function definition followed by docstring (like the example)
    { pattern = '(.-):%s*"""(.-)"""', description = 'Function definition joined with docstring' },
    { pattern = '(.-):%s*"(.+)"', description = 'Function definition joined with string' },
    { pattern = '(.-):%s*#(.+)', description = 'Code line joined with comment' },
  }
  
  for _, check in ipairs(patterns_to_check) do
    local match1, match2 = context_text:match(check.pattern)
    if match1 and match2 then
      return {
        line = line_num,
        type = 'formatting_issue',
        message = check.description .. ': ' .. context_text:sub(1, 60) .. (context_text:len() > 60 and '...' or ''),
        severity = 'warning',
        original_text = context_text,
        suggested_fix = match1 .. ':\n    """' .. match2 .. '"""' -- Example fix
      }
    end
  end
  
  -- Generic case: line not found in original
  return {
    line = line_num,
    type = 'context_mismatch',
    message = 'Context line not found in original file: ' .. context_text:sub(1, 50) .. (context_text:len() > 50 and '...' or ''),
    severity = 'warning',
    original_text = context_text
  }
end

--- Attempts to fix formatting issues in context lines
-- @param context_text The problematic context text
-- @param original_lines Array of lines from the original file
-- @return string|nil: Fixed text or nil if can't fix
function Validation._fix_context_line_formatting(context_text, original_lines)
  -- Try to find the correct formatting by looking for partial matches
  
  -- Case 1: Function definition joined with docstring
  local func_part, docstring = context_text:match('(.-):%s*"""(.-)"""')
  if func_part and docstring then
    -- Check if the function definition alone exists in the original
    for _, orig_line in ipairs(original_lines) do
      if orig_line:find(func_part, 1, true) and orig_line:match(':%s*$') then
        -- Found the function definition, return the original line
        return orig_line
      end
    end
  end
  
  -- Case 2: Look for similar lines with different formatting
  local context_words = {}
  for word in context_text:gmatch('%S+') do
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

--- Fixes function definition joined with docstring by splitting into separate lines
-- @param context_text The problematic context text with joined function and docstring
-- @param original_lines Array of lines from the original file
-- @return table|nil: Array of fixed lines [function_def, docstring] or nil if can't fix
function Validation._fix_joined_function_docstring(context_text, original_lines)
  -- Match function definition joined with docstring
  local func_part, docstring = context_text:match('(.-):%s*"""(.-)"""')
  if not func_part or not docstring then
    return nil
  end
  
  -- Find the correct function definition in the original file
  local correct_func_line = nil
  for _, orig_line in ipairs(original_lines) do
    if orig_line:find(func_part, 1, true) and orig_line:match(':%s*$') then
      correct_func_line = orig_line
      break
    end
  end
  
  if not correct_func_line then
    -- If we can't find the exact function, construct it from the parsed part
    correct_func_line = func_part .. ':'
  end
  
  -- Find the correct docstring formatting from the original file
  local correct_docstring_line = nil
  local docstring_pattern = '"""' .. vim.pesc(docstring) .. '"""'
  for _, orig_line in ipairs(original_lines) do
    if orig_line:match(docstring_pattern) then
      correct_docstring_line = orig_line
      break
    end
  end
  
  if not correct_docstring_line then
    -- If we can't find the exact docstring, construct it with proper indentation
    correct_docstring_line = '    """' .. docstring .. '"""'
  end
  
  return { correct_func_line, correct_docstring_line }
end

return Validation
