-- vibe-coding/cache.lua
-- Simple LRU cache implementation for performance optimizations

local Cache = {}
Cache.__index = Cache

--- Creates a new LRU cache
-- @param max_size Maximum number of items to cache
-- @return Cache: New cache instance
function Cache.new(max_size)
  local self = setmetatable({}, Cache)
  self.max_size = max_size or 100
  self.items = {}
  self.access_order = {}
  self.size = 0
  return self
end

--- Gets an item from the cache
-- @param key The key to look up
-- @return any: The cached value or nil if not found
function Cache:get(key)
  local item = self.items[key]
  if item then
    -- Move to end of access order (most recently used)
    self:_update_access_order(key)
    return item.value
  end
  return nil
end

--- Sets an item in the cache
-- @param key The key to store under
-- @param value The value to store
function Cache:set(key, value)
  if self.items[key] then
    -- Update existing item
    self.items[key].value = value
    self:_update_access_order(key)
  else
    -- Add new item
    if self.size >= self.max_size then
      self:_evict_least_recently_used()
    end

    self.items[key] = { value = value, timestamp = os.time() }
    table.insert(self.access_order, key)
    self.size = self.size + 1
  end
end

--- Clears all items from the cache
function Cache:clear()
  self.items = {}
  self.access_order = {}
  self.size = 0
end

--- Gets cache statistics
-- @return table: Stats about the cache
function Cache:stats()
  return {
    size = self.size,
    max_size = self.max_size,
    hit_ratio = 0, -- TODO: implement hit tracking
  }
end

--- Updates the access order for a key
-- @param key The key that was accessed
function Cache:_update_access_order(key)
  -- Remove from current position
  for i, k in ipairs(self.access_order) do
    if k == key then
      table.remove(self.access_order, i)
      break
    end
  end

  -- Add to end (most recently used)
  table.insert(self.access_order, key)
end

--- Evicts the least recently used item
function Cache:_evict_least_recently_used()
  if #self.access_order > 0 then
    local lru_key = table.remove(self.access_order, 1)
    self.items[lru_key] = nil
    self.size = self.size - 1
  end
end

-- Global cache instances for different purposes
local _file_search_cache = Cache.new(50)
local _path_resolution_cache = Cache.new(100)

--- Cached file search function
-- @param filename The filename to search for
-- @return table: List of file paths
function Cache.cached_file_search(filename)
  local cached = _file_search_cache:get(filename)
  if cached then
    return cached
  end

  -- Perform actual search
  local find_result = vim.fn.system(string.format('find . -name %s -type f 2>/dev/null', vim.fn.shellescape(filename)))
  local candidates = {}

  if vim.v.shell_error == 0 and find_result ~= '' then
    candidates = vim.split(find_result, '\n', { plain = true })
    -- Filter out empty lines
    local valid_candidates = {}
    for _, candidate in ipairs(candidates) do
      if candidate ~= '' then
        table.insert(valid_candidates, candidate:gsub('^%./', ''))
      end
    end
    candidates = valid_candidates
  end

  _file_search_cache:set(filename, candidates)
  return candidates
end

--- Cached path resolution function
-- @param path The path to resolve
-- @return string|nil: The resolved path or nil
function Cache.cached_path_resolution(path)
  local cached = _path_resolution_cache:get(path)
  if cached then
    return cached
  end

  -- This would be implemented by the actual path resolution logic
  -- For now, just return nil to indicate cache miss
  return nil
end

--- Sets a cached path resolution
-- @param path The original path
-- @param resolved_path The resolved path
function Cache.set_path_resolution(path, resolved_path)
  _path_resolution_cache:set(path, resolved_path)
end

--- Clears all caches
function Cache.clear_all()
  _file_search_cache:clear()
  _path_resolution_cache:clear()
end

return Cache
