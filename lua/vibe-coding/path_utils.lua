-- vibe-coding/path_utils.lua
-- Path utility functions for diff processing

local Cache = require 'vibe-coding.cache'
local PathUtils = {}

--- Cleans up malformed paths by removing extra dashes and spaces
-- @param path The path to clean
-- @return string: The cleaned path
function PathUtils.clean_path(path)
  if not path then
    return nil
  end
  return path:gsub('^[-%s]*', '')
end

--- Checks if a path looks like a valid file path
-- @param path The path to check
-- @return boolean: True if it looks like a file path
function PathUtils.looks_like_file(path)
  if not path then
    return false
  end

  -- Basic filtering: must not be just whitespace and should look path-like
  -- Avoid treating obvious code content as file paths
  if not path:match '%S' then
    return false
  end

  -- Must not contain obvious code patterns
  if path:match '[={}%[%]%(%)"\']' then
    return false
  end

  -- Should contain path-like characters (letters, numbers, dots, slashes, hyphens, underscores)
  return path:match '^[%w%./_-]+$' ~= nil
end

--- Finds the actual file path by searching the filesystem intelligently.
-- @param original_path The path from the diff header.
-- @return string|nil: The resolved path or nil if not found.
function PathUtils.resolve_file_path(original_path)
  if not original_path then
    return nil
  end

  -- Check cache first
  local cached = Cache.cached_path_resolution(original_path)
  if cached then
    return cached
  end

  -- Clean up the path first
  local cleaned_path = original_path

  -- Remove single-letter prefixes with slash (generic approach for VCS prefixes)
  cleaned_path = cleaned_path:gsub('^%w/', '')

  -- Remove leading slash if present
  cleaned_path = cleaned_path:gsub('^/', '')

  -- Strategy 1: Try the path as-is (relative to cwd)
  if vim.fn.filereadable(cleaned_path) == 1 then
    Cache.set_path_resolution(original_path, cleaned_path)
    return cleaned_path
  end

  -- Strategy 2: If it's an absolute path, check if it exists
  if original_path:match '^/' and vim.fn.filereadable(original_path) == 1 then
    -- Convert absolute path to relative path from cwd
    local cwd = vim.fn.getcwd()
    if original_path:find(cwd, 1, true) == 1 then
      local relative = original_path:sub(#cwd + 2) -- +2 to skip the trailing slash
      Cache.set_path_resolution(original_path, relative)
      return relative
    end
    Cache.set_path_resolution(original_path, original_path)
    return original_path
  end

  -- Strategy 3: Extract just the filename and search for it
  local filename = cleaned_path:match '([^/]+)$'
  if filename then
    local found_path = PathUtils._search_for_file(filename, cleaned_path)
    if found_path then
      Cache.set_path_resolution(original_path, found_path)
      return found_path
    end
  end

  -- Strategy 4: Try searching in existing directories
  local dir_path = PathUtils._search_in_directories(cleaned_path, filename)
  if dir_path then
    Cache.set_path_resolution(original_path, dir_path)
    return dir_path
  end

  -- Strategy 5: Try removing directory components from the front
  local path_components = vim.split(cleaned_path, '/', { plain = true })
  if #path_components > 1 then
    for i = 2, #path_components do
      local shorter_path = table.concat(path_components, '/', i)
      if vim.fn.filereadable(shorter_path) == 1 then
        Cache.set_path_resolution(original_path, shorter_path)
        return shorter_path
      end
    end
  end

  -- Not found - cache the negative result
  Cache.set_path_resolution(original_path, nil)
  return nil
end

--- Searches for a file using the find command
-- @param filename The filename to search for
-- @param original_path The original path for scoring
-- @return string|nil: The best matching path or nil
function PathUtils._search_for_file(filename, original_path)
  -- Use cached file search for performance
  local candidates = Cache.cached_file_search(filename)

  if #candidates == 1 then
    -- Exactly one match found
    return candidates[1]
  elseif #candidates > 1 then
    -- Multiple matches - find the best one
    return PathUtils._find_best_match(candidates, original_path)
  end

  return nil
end

--- Finds the best matching path from multiple candidates
-- @param candidates List of candidate paths
-- @param original_path The original path to match against
-- @return string|nil: The best matching path
function PathUtils._find_best_match(candidates, original_path)
  local path_parts = {}
  for part in original_path:gmatch '[^/]+' do
    table.insert(path_parts, part)
  end

  local best_match = nil
  local best_score = 0

  for _, candidate in ipairs(candidates) do
    local score = 0

    -- Score based on how many path components match
    for _, part in ipairs(path_parts) do
      if candidate:find(part, 1, true) then
        score = score + 1
      end
    end

    -- Bonus for matching directory structure
    if original_path:find '/' and candidate:find '/' then
      local original_dirs = vim.split(original_path, '/', { plain = true })
      local candidate_dirs = vim.split(candidate, '/', { plain = true })

      -- Check if the directory structure is similar
      local dir_matches = 0
      for i = 1, math.min(#original_dirs - 1, #candidate_dirs - 1) do
        if original_dirs[#original_dirs - i] == candidate_dirs[#candidate_dirs - i] then
          dir_matches = dir_matches + 1
        else
          break
        end
      end
      score = score + dir_matches * 2 -- Weight directory matches more
    end

    if score > best_score then
      best_score = score
      best_match = candidate
    end
  end

  -- Return best match, or first one if no clear winner
  return best_match or candidates[1]
end

--- Searches for files in all existing directories
-- @param cleaned_path The cleaned path to search for
-- @param filename The filename to search for
-- @return string|nil: The found path or nil
function PathUtils._search_in_directories(cleaned_path, filename)
  -- Get all directories in current working directory
  local dirs = {}
  local handle = vim.loop.fs_scandir '.'
  if handle then
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      if type == 'directory' and not name:match '^%.' then -- Skip hidden directories
        table.insert(dirs, name)
      end
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end

  -- Try the full path in each directory
  for _, dir in ipairs(dirs) do
    local dir_path = dir .. '/' .. cleaned_path
    if vim.fn.filereadable(dir_path) == 1 then
      return dir_path
    end

    -- Try with just filename if provided
    if filename then
      dir_path = dir .. '/' .. filename
      if vim.fn.filereadable(dir_path) == 1 then
        return dir_path
      end
    end
  end

  return nil
end

return PathUtils
