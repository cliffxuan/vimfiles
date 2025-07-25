-- Language-agnostic fixture loader for directory-based fixtures
-- Provides utilities to load and manage test fixtures in the new format

local M = {}

-- Get the directory where this file is located
local fixtures_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h')

--- Simple JSON decoder for meta.json files
local function decode_json(json_str)
  -- Simple JSON decoder - handles basic objects only
  local result = {}

  -- Remove outer braces and whitespace
  json_str = json_str:gsub('^%s*{%s*', ''):gsub('%s*}%s*$', '')

  -- Split by comma and parse key-value pairs
  for pair in json_str:gmatch '[^,]+' do
    local key, value = pair:match '%s*"([^"]+)"%s*:%s*(.+)%s*'
    if key and value then
      -- Handle different value types
      if value:match '^".*"$' then
        -- String value
        result[key] = value:gsub('^"', ''):gsub('"$', ''):gsub('\\"', '"'):gsub('\\n', '\n')
      elseif value == 'true' then
        result[key] = true
      elseif value == 'false' then
        result[key] = false
      elseif value == 'null' then
        result[key] = nil
      elseif value:match '^%[.*%]$' then
        -- Array value - simple parsing for string arrays
        result[key] = {}
        local array_content = value:gsub('^%[%s*', ''):gsub('%s*%]$', '')
        if array_content ~= '' then
          for item in array_content:gmatch '"([^"]*)"' do
            table.insert(result[key], item)
          end
        end
      elseif tonumber(value) then
        result[key] = tonumber(value)
      else
        result[key] = value
      end
    end
  end

  return result
end

--- Load content from a file
-- @param file_path string: Path to the file to load
-- @return string|nil: Content of the file, or nil if file doesn't exist
local function load_file_content(file_path)
  if vim.fn.filereadable(file_path) ~= 1 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(file_path), '\n')
  return content
end

--- Load a fixture from a directory
-- @param fixture_path string: Path to fixture directory (e.g., 'pass/basic_modification')
-- @return table: The fixture data
function M.load_fixture(fixture_path)
  local full_path = fixtures_dir .. '/' .. fixture_path

  if vim.fn.isdirectory(full_path) ~= 1 then
    error('Fixture directory not found: ' .. full_path)
  end

  -- Load meta.json
  local meta_path = full_path .. '/meta.json'
  local meta_content = load_file_content(meta_path)
  if not meta_content then
    error('Fixture meta.json not found: ' .. meta_path)
  end

  local fixture = decode_json(meta_content)

  -- Load original content
  local original_files = vim.fn.glob(full_path .. '/original.*', false, true)
  if #original_files > 0 then
    fixture.original_content = load_file_content(original_files[1])
  end

  -- Load diff content
  local diff_path = full_path .. '/diff'
  fixture.diff_content = load_file_content(diff_path)

  -- Load expected content (only for successful tests)
  if fixture.should_succeed then
    local expected_files = vim.fn.glob(full_path .. '/expected.*', false, true)
    if #expected_files > 0 then
      fixture.expected_content = load_file_content(expected_files[1])
    end
  end

  -- Validate fixture structure
  M.validate_fixture(fixture, fixture_path)

  -- Add metadata
  fixture._path = fixture_path
  fixture._full_path = full_path

  return fixture
end

--- Load all fixtures from a category directory
-- @param category string: Category name (e.g., 'pass', 'fail')
-- @return table: Array of fixture data
function M.load_category(category)
  local category_dir = fixtures_dir .. '/' .. category

  if vim.fn.isdirectory(category_dir) ~= 1 then
    error('Category directory not found: ' .. category_dir)
  end

  local fixtures = {}
  local dirs = vim.fn.glob(category_dir .. '/*', false, true)

  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local fixture_name = vim.fn.fnamemodify(dir, ':t')
      local fixture_path = category .. '/' .. fixture_name

      local ok, fixture = pcall(M.load_fixture, fixture_path)
      if ok then
        table.insert(fixtures, fixture)
      else
        error('Failed to load fixture: ' .. fixture_path .. '\nError: ' .. fixture)
      end
    end
  end

  -- Sort by name for consistent ordering
  table.sort(fixtures, function(a, b)
    return a.name < b.name
  end)

  return fixtures
end

--- Load all fixtures from all categories
-- @return table: Array of all fixture data
function M.load_all()
  local all_fixtures = {}

  -- Load passing fixtures
  local pass_fixtures = M.load_category 'pass'
  for _, fixture in ipairs(pass_fixtures) do
    fixture._category = 'pass'
    table.insert(all_fixtures, fixture)
  end

  -- Load failing fixtures
  local fail_fixtures = M.load_category 'fail'
  for _, fixture in ipairs(fail_fixtures) do
    fixture._category = 'fail'
    table.insert(all_fixtures, fixture)
  end

  return all_fixtures
end

--- Get all available categories
-- @return table: Array of category names
function M.get_categories()
  local categories = {}
  local dirs = vim.fn.glob(fixtures_dir .. '/*', false, true)

  for _, dir in ipairs(dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local category_name = vim.fn.fnamemodify(dir, ':t')
      table.insert(categories, category_name)
    end
  end

  table.sort(categories)
  return categories
end

--- Validate fixture structure
-- @param fixture table: The fixture data to validate
-- @param fixture_path string: Path for error reporting
function M.validate_fixture(fixture, fixture_path)
  fixture_path = fixture_path or 'unknown'

  -- Required fields
  local required_fields = { 'name', 'description', 'should_succeed' }

  for _, field in ipairs(required_fields) do
    if fixture[field] == nil then
      error('Missing required field "' .. field .. '" in fixture: ' .. fixture_path)
    end
  end

  -- Content fields - must have content after loading (allow empty string for new file creation)
  if fixture.original_content == nil then
    error('Missing required "original_content" in fixture: ' .. fixture_path)
  end

  if fixture.diff_content == nil then
    error('Missing required "diff_content" in fixture: ' .. fixture_path)
  end

  -- Type validation
  if type(fixture.name) ~= 'string' then
    error('Field "name" must be a string in fixture: ' .. fixture_path)
  end

  if type(fixture.description) ~= 'string' then
    error('Field "description" must be a string in fixture: ' .. fixture_path)
  end

  if type(fixture.should_succeed) ~= 'boolean' then
    error('Field "should_succeed" must be a boolean in fixture: ' .. fixture_path)
  end

  -- Conditional validation
  if fixture.should_succeed then
    if not fixture.expected_content then
      error('Missing required "expected_content" when should_succeed=true in fixture: ' .. fixture_path)
    end
  else
    if not fixture.expected_error_pattern then
      error('Field "expected_error_pattern" is required when should_succeed=false in fixture: ' .. fixture_path)
    end
  end
end

-- Test case creation functions (simplified versions)
function M.create_test_case(fixture)
  return function()
    local vibe = require 'vibe-coding'

    -- Simple mock setup
    local original_read = vibe.Utils.read_file_content
    local original_write = vibe.Utils.write_file
    local write_calls = {}

    vibe.Utils.read_file_content = function(filepath)
      return fixture.original_content, nil
    end

    vibe.Utils.write_file = function(filepath, content)
      table.insert(write_calls, { filepath = filepath, content = content })
      return true, nil
    end

    -- Parse and apply the diff
    local parsed_diff, parse_err = vibe.VibePatcher.parse_diff(fixture.diff_content)

    if fixture.should_succeed then
      -- Test should succeed
      assert.is_nil(parse_err, 'Failed to parse diff: ' .. (parse_err or ''))
      assert.is_not_nil(parsed_diff, 'Parsed diff should not be nil')

      local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)
      assert.is_true(success, 'Expected apply_diff to succeed: ' .. (msg or ''))

      -- Verify file was written with expected content
      assert.are.equal(1, #write_calls, 'Expected write_file to be called once')
      local expected_lines = vim.split(fixture.expected_content, '\n', { plain = true, trimempty = false })
      assert.are.equal(fixture.file_path or parsed_diff.new_path, write_calls[1].filepath)
      assert.are.same(expected_lines, write_calls[1].content)
    else
      -- Test should fail
      if parsed_diff then
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)
        assert.is_false(success, 'Expected apply_diff to fail')
        assert.is_true(
          (msg or ''):find(fixture.expected_error_pattern) ~= nil,
          'Error message should contain expected pattern'
        )
      else
        -- Parse error is also acceptable for error cases
        assert.is_true(
          (parse_err or ''):find(fixture.expected_error_pattern) ~= nil,
          'Parse error should contain expected pattern'
        )
      end
    end

    -- Restore original functions
    vibe.Utils.read_file_content = original_read
    vibe.Utils.write_file = original_write
  end
end

function M.create_integration_test_case(fixture)
  return function()
    local vibe = require 'vibe-coding'

    -- Simple mock setup
    local original_read = vibe.Utils.read_file_content
    local original_write = vibe.Utils.write_file
    local write_calls = {}

    vibe.Utils.read_file_content = function(filepath)
      return fixture.original_content, nil
    end

    vibe.Utils.write_file = function(filepath, content)
      table.insert(write_calls, { filepath = filepath, content = content })
      return true, nil
    end

    -- Test the full integration pipeline
    local result = vibe.VibePatcher.process_and_apply_patch(fixture.diff_content, {
      silent = true,
      skip_buffer_refresh = true,
      force_builtin_engine = true,
    })

    if fixture.should_succeed then
      -- Test should succeed
      assert.is_true(result.success, 'Expected process_and_apply_patch to succeed: ' .. (result.message or ''))

      -- Check if this is a file deletion case (new_path is /dev/null)
      if result.parsed_diff and result.parsed_diff.new_path == '/dev/null' then
        -- File deletion - only temp diff file should be written
        assert.are.equal(1, #write_calls, 'Expected write_file to be called once (temp diff only) for file deletion')
        assert.is_not_nil(result.message:find 'Skipped file deletion', 'Expected deletion message')
      else
        -- Normal file modification - temp diff + actual file content
        assert.are.equal(2, #write_calls, 'Expected write_file to be called twice (temp diff + content)')
        local expected_lines = vim.split(fixture.expected_content, '\n', { plain = true, trimempty = false })

        -- The second call should be the actual file content
        local content_write_call = write_calls[2]
        assert.are.equal(fixture.file_path or result.parsed_diff.new_path, content_write_call.filepath)
        assert.are.same(expected_lines, content_write_call.content)
      end
    else
      -- Test should fail
      assert.is_false(result.success, 'Expected process_and_apply_patch to fail')
      assert.is_true(
        (result.message or ''):find(fixture.expected_error_pattern) ~= nil,
        'Error message should contain expected pattern'
      )
    end

    -- Restore original functions
    vibe.Utils.read_file_content = original_read
    vibe.Utils.write_file = original_write
  end
end

return M
