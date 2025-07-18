-- Integration tests for the full patch validation and application pipeline
-- Tests the functionality equivalent to running VibeApplyPatch

describe('Integration Tests - Full Patch Pipeline', function()
  local fixtures = require 'tests.fixtures.fixture_loader'
  local vibe

  before_each(function()
    -- Set up telescope mocks BEFORE requiring the module
    package.loaded['telescope'] = {
      pickers = {
        new = function()
          return {}
        end,
      },
      finders = {
        new_table = function()
          return {}
        end,
      },
      config = { values = { sorter = {
        get_sorter = function()
          return {}
        end,
      } } },
      actions = {},
      ['actions.state'] = {},
    }

    package.loaded['telescope.pickers'] = {
      new = function()
        return {}
      end,
    }

    package.loaded['telescope.finders'] = {
      new_table = function()
        return {}
      end,
    }

    package.loaded['telescope.config'] = {
      values = { sorter = {
        get_sorter = function()
          return {}
        end,
      } },
    }

    package.loaded['telescope.actions'] = {}

    package.loaded['telescope.actions.state'] = {}

    package.loaded['telescope.previewers'] = {
      new_termopen_previewer = function()
        return {}
      end,
    }

    package.loaded['telescope.sorters'] = {
      get_generic_fuzzy_sorter = function()
        return {}
      end,
    }

    -- Clear any existing module cache for the plugin to ensure clean state
    package.loaded['vibe-coding'] = nil
    vibe = require 'vibe-coding'
  end)

  after_each(function()
    -- Clean up mocks
    package.loaded['telescope'] = nil
    package.loaded['telescope.pickers'] = nil
    package.loaded['telescope.finders'] = nil
    package.loaded['telescope.config'] = nil
    package.loaded['telescope.actions'] = nil
    package.loaded['telescope.actions.state'] = nil
    package.loaded['telescope.previewers'] = nil
    package.loaded['telescope.sorters'] = nil
    package.loaded['vibe-coding'] = nil
  end)

  describe('Core Pipeline Function', function()
    it('should have process_and_apply_patch function', function()
      assert.is_function(vibe.VibePatcher.process_and_apply_patch)
    end)

    it('should return proper result structure', function()
      local simple_diff = [[
--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,1 @@
-old line
+new line
]]

      -- Mock file operations
      local original_read = vibe.Utils.read_file_content
      local original_write = vibe.Utils.write_file

      vibe.Utils.read_file_content = function()
        return 'old line', nil
      end
      vibe.Utils.write_file = function()
        return true, nil
      end

      local result = vibe.VibePatcher.process_and_apply_patch(simple_diff, {
        silent = true,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      -- Restore mocks
      vibe.Utils.read_file_content = original_read
      vibe.Utils.write_file = original_write

      -- Verify result structure
      assert.is_table(result)
      assert.is_boolean(result.success)
      assert.is_string(result.message)
      assert.is_table(result.validation_issues)
      assert.is_not_nil(result.validated_diff)
      assert.is_boolean(result.applied_with_external_tool)
    end)
  end)

  describe('Integration Test Fixtures', function()
    local integration_fixtures = fixtures.load_category 'integration'

    it('should load integration fixtures', function()
      assert.is_true(#integration_fixtures > 0, 'Should have integration fixtures')
    end)

    for _, fixture in ipairs(integration_fixtures) do
      it(fixture.name, fixtures.create_integration_test_case(fixture))
    end
  end)

  describe('Validation Pipeline Integration', function()
    it('should handle smart validation with context fixes', function()
      local fixture = fixtures.load_fixture 'integration/smart_validation_success'
      local test_case = fixtures.create_integration_test_case(fixture)
      test_case()
    end)

    it('should handle path resolution fixes', function()
      local fixture = fixtures.load_fixture 'integration/path_resolution_fix'
      local test_case = fixtures.create_integration_test_case(fixture)
      test_case()
    end)

    it('should fail appropriately on validation errors', function()
      local fixture = fixtures.load_fixture 'integration/validation_error_case'
      local test_case = fixtures.create_integration_test_case(fixture)
      test_case()
    end)

    it('should handle external tool fallback', function()
      local fixture = fixtures.load_fixture 'integration/external_tool_fallback'
      local test_case = fixtures.create_integration_test_case(fixture)
      test_case()
    end)
  end)

  describe('Options and Configuration', function()
    it('should respect silent option', function()
      local diff_content = [[
--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,1 @@
-old line
+new line
]]

      -- Mock file operations
      local original_read = vibe.Utils.read_file_content
      local original_write = vibe.Utils.write_file
      local original_notify = vim.notify
      local notify_calls = {}

      vibe.Utils.read_file_content = function()
        return 'old line', nil
      end
      vibe.Utils.write_file = function()
        return true, nil
      end
      vim.notify = function(msg, level)
        table.insert(notify_calls, { msg = msg, level = level })
      end

      -- Test with silent = false (should notify)
      local result1 = vibe.VibePatcher.process_and_apply_patch(diff_content, {
        silent = false,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      local notify_count_verbose = #notify_calls
      notify_calls = {}

      -- Test with silent = true (should not notify)
      local result2 = vibe.VibePatcher.process_and_apply_patch(diff_content, {
        silent = true,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      local notify_count_silent = #notify_calls

      -- Restore mocks
      vibe.Utils.read_file_content = original_read
      vibe.Utils.write_file = original_write
      vim.notify = original_notify

      -- Silent mode should have fewer (or no) notifications
      assert.is_true(notify_count_silent < notify_count_verbose, 'Silent mode should reduce notifications')
    end)

    it('should respect force_builtin_engine option', function()
      local diff_content = [[
--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,1 @@
-old line
+new line
]]

      -- Mock file operations
      local original_read = vibe.Utils.read_file_content
      local original_write = vibe.Utils.write_file

      vibe.Utils.read_file_content = function()
        return 'old line', nil
      end
      vibe.Utils.write_file = function()
        return true, nil
      end

      local result = vibe.VibePatcher.process_and_apply_patch(diff_content, {
        silent = true,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      -- Restore mocks
      vibe.Utils.read_file_content = original_read
      vibe.Utils.write_file = original_write

      -- When forced to use builtin engine, should not use external tool
      assert.is_false(result.applied_with_external_tool, 'Should not use external tool when forced to builtin')
    end)
  end)

  describe('Error Handling', function()
    it('should handle parse errors gracefully', function()
      local invalid_diff = 'This is not a valid diff'

      local result = vibe.VibePatcher.process_and_apply_patch(invalid_diff, {
        silent = true,
        skip_buffer_refresh = true,
      })

      assert.is_false(result.success)
      assert.is_true(result.message:find 'Failed to parse' ~= nil)
    end)

    it('should handle file read errors', function()
      local diff_content = [[
--- a/nonexistent.txt
+++ b/nonexistent.txt
@@ -1,1 +1,1 @@
-old line
+new line
]]

      -- Mock file read to fail
      local original_read = vibe.Utils.read_file_content
      vibe.Utils.read_file_content = function()
        return nil, 'File not found'
      end

      local result = vibe.VibePatcher.process_and_apply_patch(diff_content, {
        silent = true,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      -- Restore mock
      vibe.Utils.read_file_content = original_read

      assert.is_false(result.success)
    end)

    it('should handle file write errors', function()
      local diff_content = [[
--- a/test.txt
+++ b/test.txt
@@ -1,1 +1,1 @@
-old line
+new line
]]

      -- Mock file operations
      local original_read = vibe.Utils.read_file_content
      local original_write = vibe.Utils.write_file

      vibe.Utils.read_file_content = function()
        return 'old line', nil
      end
      vibe.Utils.write_file = function()
        return false, 'Write failed'
      end

      local result = vibe.VibePatcher.process_and_apply_patch(diff_content, {
        silent = true,
        force_builtin_engine = true,
        skip_buffer_refresh = true,
      })

      -- Restore mocks
      vibe.Utils.read_file_content = original_read
      vibe.Utils.write_file = original_write

      assert.is_false(result.success)
      assert.is_true(result.message:find 'Write failed' ~= nil or result.message:find 'Failed to write' ~= nil)
    end)
  end)
end)
