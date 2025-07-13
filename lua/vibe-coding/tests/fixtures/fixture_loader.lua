-- Test fixture loader for VibeApplyPatch tests
-- Provides utilities to load and manage test fixtures

local M = {}

-- Get the directory where this file is located
local fixtures_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h')

--- Trim leading and trailing whitespace from a string
-- This handles the case where fixture content is defined with [[ ]] brackets
-- and we want to trim the leading/trailing newlines and whitespace for cleaner editing
-- @param str string: The string to trim
-- @return string: The trimmed string
local function trim_content(str)
  if type(str) ~= 'string' then
    return str
  end

  -- Only trim the specific newlines that come after [[ and before ]]
  -- First, trim a single trailing newline at the start (after [[)
  str = str:gsub('^%s*\n', '')
  -- Then, trim a single leading newline at the end (before ]])
  str = str:gsub('\n%s*$', '')

  return str
end

--- Load content from an external text file
-- @param fixture_dir string: Directory containing the fixture
-- @param filename string: Name of the text file to load
-- @return string|nil: Content of the file, or nil if file doesn't exist
local function load_external_content(fixture_dir, filename)
  local content_path = fixture_dir .. '/' .. filename

  if vim.fn.filereadable(content_path) ~= 1 then
    return nil
  end

  local content = table.concat(vim.fn.readfile(content_path), '\n')
  return content
end

--- Try to load external content using convention-based naming
-- @param fixture_dir string: Directory containing the fixture
-- @param fixture_name string: Base name of the fixture (without .lua extension)
-- @param content_type string: Type of content ('original', 'diff', 'expected')
-- @return string|nil: Content of the file, or nil if file doesn't exist
local function try_load_conventional_content(fixture_dir, fixture_name, content_type)
  local filename = fixture_name .. '_' .. content_type .. '.txt'
  return load_external_content(fixture_dir, filename)
end

--- Load a single fixture file
-- @param fixture_path string: Path relative to fixtures directory (e.g., 'simple/basic_modification')
-- @return table: The fixture data
function M.load_fixture(fixture_path)
  -- Remove .lua extension if provided
  local clean_path = fixture_path:gsub('%.lua$', '')

  local full_path = fixtures_dir .. '/' .. clean_path .. '.lua'

  if vim.fn.filereadable(full_path) ~= 1 then
    error('Fixture file not found: ' .. full_path)
  end

  local ok, fixture = pcall(dofile, full_path)
  if not ok then
    error('Failed to load fixture: ' .. fixture_path .. '\nError: ' .. fixture)
  end

  -- Get the directory containing this fixture file and fixture name
  local fixture_dir = vim.fn.fnamemodify(full_path, ':h')
  local fixture_name = vim.fn.fnamemodify(full_path, ':t:r')

  -- Load content from external files if specified (takes priority over inline content)
  if fixture.original_content_file then
    local content = load_external_content(fixture_dir, fixture.original_content_file)
    if not content then
      error('External original content file not found: ' .. fixture_dir .. '/' .. fixture.original_content_file)
    end
    fixture.original_content = content
  elseif not fixture.original_content then
    -- Try convention-based loading: {fixture_name}_original.txt
    fixture.original_content = try_load_conventional_content(fixture_dir, fixture_name, 'original')
  end

  if fixture.diff_content_file then
    local content = load_external_content(fixture_dir, fixture.diff_content_file)
    if not content then
      error('External diff content file not found: ' .. fixture_dir .. '/' .. fixture.diff_content_file)
    end
    fixture.diff_content = content
  elseif not fixture.diff_content then
    -- Try convention-based loading: {fixture_name}_diff.txt
    fixture.diff_content = try_load_conventional_content(fixture_dir, fixture_name, 'diff')
  end

  if fixture.expected_content_file then
    local content = load_external_content(fixture_dir, fixture.expected_content_file)
    if not content then
      error('External expected content file not found: ' .. fixture_dir .. '/' .. fixture.expected_content_file)
    end
    fixture.expected_content = content
  elseif not fixture.expected_content and fixture.should_succeed then
    -- Try convention-based loading: {fixture_name}_expected.txt
    fixture.expected_content = try_load_conventional_content(fixture_dir, fixture_name, 'expected')
  end

  -- Trim whitespace from content fields for cleaner editing (only if loaded inline)
  if fixture.original_content and not fixture.original_content_file then
    fixture.original_content = trim_content(fixture.original_content)
  end
  if fixture.diff_content and not fixture.diff_content_file then
    fixture.diff_content = trim_content(fixture.diff_content)
  end
  if fixture.expected_content and not fixture.expected_content_file then
    fixture.expected_content = trim_content(fixture.expected_content)
  end

  -- Validate fixture structure
  M.validate_fixture(fixture, fixture_path)

  -- Add metadata
  fixture._path = fixture_path
  fixture._full_path = full_path

  return fixture
end

--- Load all fixtures from a category directory
-- @param category string: Category name (e.g., 'simple', 'complex', 'error_cases')
-- @return table: Array of fixture data
function M.load_category(category)
  local category_dir = fixtures_dir .. '/' .. category

  if vim.fn.isdirectory(category_dir) ~= 1 then
    error('Category directory not found: ' .. category_dir)
  end

  local fixtures = {}
  local files = vim.fn.glob(category_dir .. '/*.lua', false, true)

  for _, file in ipairs(files) do
    local fixture_name = vim.fn.fnamemodify(file, ':t:r')
    local fixture_path = category .. '/' .. fixture_name

    local ok, fixture = pcall(M.load_fixture, fixture_path)
    if ok then
      table.insert(fixtures, fixture)
    else
      error('Failed to load fixture: ' .. fixture_path .. '\nError: ' .. fixture)
    end
  end

  -- Sort by name for consistent ordering
  table.sort(fixtures, function(a, b)
    return a.name < b.name
  end)

  return fixtures
end

--- Load all fixtures from all categories
-- @return table: Array of all fixture data organized by category
function M.load_all()
  local categories = { 'simple', 'complex', 'error_cases' }
  local all_fixtures = {}

  for _, category in ipairs(categories) do
    local category_fixtures = M.load_category(category)
    for _, fixture in ipairs(category_fixtures) do
      fixture._category = category
      table.insert(all_fixtures, fixture)
    end
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
      -- Skip non-category directories
      if category_name ~= 'README.md' and not category_name:match '%.lua$' then
        table.insert(categories, category_name)
      end
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

  -- Content fields - must have content after loading (inline, explicit file, or convention-based)
  if not fixture.original_content then
    error('Missing required "original_content" in fixture: ' .. fixture_path .. ' (not found inline, via explicit file, or convention-based)')
  end

  if not fixture.diff_content then
    error('Missing required "diff_content" in fixture: ' .. fixture_path .. ' (not found inline, via explicit file, or convention-based)')
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

  if fixture.original_content and type(fixture.original_content) ~= 'string' then
    error('Field "original_content" must be a string in fixture: ' .. fixture_path)
  end

  if fixture.diff_content and type(fixture.diff_content) ~= 'string' then
    error('Field "diff_content" must be a string in fixture: ' .. fixture_path)
  end

  -- Conditional validation
  if fixture.should_succeed then
    if not fixture.expected_content then
      error('Missing required "expected_content" when should_succeed=true in fixture: ' .. fixture_path .. ' (not found inline, via explicit file, or convention-based)')
    end
    if fixture.expected_content and type(fixture.expected_content) ~= 'string' then
      error('Field "expected_content" must be a string in fixture: ' .. fixture_path)
    end
  else
    if not fixture.expected_error_pattern then
      error('Field "expected_error_pattern" is required when should_succeed=false in fixture: ' .. fixture_path)
    end
    if type(fixture.expected_error_pattern) ~= 'string' then
      error('Field "expected_error_pattern" must be a string in fixture: ' .. fixture_path)
    end
  end

  -- Optional fields validation
  if fixture.tags and type(fixture.tags) ~= 'table' then
    error('Field "tags" must be a table in fixture: ' .. fixture_path)
  end

  if fixture.file_path and type(fixture.file_path) ~= 'string' then
    error('Field "file_path" must be a string in fixture: ' .. fixture_path)
  end
end

-- Helper function to setup manual mocking
local function setup_file_mocks(read_content, write_result)
  local vibe = require 'vibe-coding'
  local read_calls = {}
  local write_calls = {}
  
  local original_read = vibe.Utils.read_file_content
  local original_write = vibe.Utils.write_file
  
  vibe.Utils.read_file_content = function(filepath)
    table.insert(read_calls, filepath)
    return read_content, nil
  end
  
  vibe.Utils.write_file = function(filepath, content)
    table.insert(write_calls, {filepath = filepath, content = content})
    return write_result or true, nil
  end
  
  return {
    read_calls = read_calls,
    write_calls = write_calls,
    restore = function()
      vibe.Utils.read_file_content = original_read
      vibe.Utils.write_file = original_write
    end
  }
end

--- Create a test case from a fixture
-- @param fixture table: The fixture data
-- @return function: A test function that can be used with testing frameworks
function M.create_test_case(fixture)
  return function()
    local vibe = require 'vibe-coding'

    local mocks = setup_file_mocks(fixture.original_content)

    -- Parse and apply the diff
    local parsed_diff, parse_err = vibe.VibePatcher.parse_diff(fixture.diff_content)

    if fixture.should_succeed then
      -- Test should succeed
      assert.is_nil(parse_err, 'Failed to parse diff: ' .. (parse_err or ''))
      assert.is_not_nil(parsed_diff, 'Parsed diff should not be nil')

      local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

      assert.is_true(success, 'Expected apply_diff to succeed: ' .. (msg or ''))

      -- Handle special case for file deletion (message is in expected_content)
      if fixture.expected_content:match '^Skipped file deletion' then
        assert.are.equal(fixture.expected_content, msg)
        assert.are.equal(0, #mocks.write_calls, 'Expected write_file to not be called')
      else
        assert.is_true(msg:find 'Successfully applied' ~= nil, 'Message should contain "Successfully applied"')
        assert.is_true(msg:find 'hunks to' ~= nil, 'Message should contain "hunks to"')

        -- Verify file was written with expected content
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        local expected_lines = vim.split(fixture.expected_content, '\n', { plain = true, trimempty = false })
        assert.are.equal(fixture.file_path or parsed_diff.new_path, mocks.write_calls[1].filepath)
        assert.are.same(expected_lines, mocks.write_calls[1].content)
      end
    else
      -- Test should fail
      if parsed_diff then
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)
        assert.is_false(success, 'Expected apply_diff to fail')
        assert.is_true(
          (msg or ''):find(fixture.expected_error_pattern) ~= nil,
          'Error message should contain expected pattern'
        )
        assert.are.equal(0, #mocks.write_calls, 'Expected write_file to not be called')
      else
        -- Parse error is also acceptable for error cases
        assert.is_true(
          (parse_err or ''):find(fixture.expected_error_pattern) ~= nil,
          'Parse error should contain expected pattern'
        )
      end
    end
    
    mocks.restore()
  end
end

return M
