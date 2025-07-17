-- Validation Module Tests (Separated during feature development)
-- These tests can be run independently when validation features are stable

---@diagnostic disable: undefined-global

describe('Validation Module Tests', function()
  local mock = require 'luassert.mock'
  local vibe -- Will be loaded after mocking

  -- Mock telescope.pickers module to avoid runtime errors in tests due to missing Telescope dependency
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

    package.loaded['telescope.previewers'] = {}
    -- Now we can safely require the module
    -- Clear any previous load of the module first
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
    package.loaded['vibe-coding'] = nil
  end)

  describe('_fix_hunk_content_line', function()
    it('should pass through valid diff lines unchanged', function()
      local validation = require 'vibe-coding.validation'

      -- Test valid context line
      local line, issue = validation._fix_hunk_content_line(' some context line', 1)
      assert.are.equal(' some context line', line)
      assert.is_nil(issue)

      -- Test valid addition line
      line, issue = validation._fix_hunk_content_line('+added line', 2)
      assert.are.equal('+added line', line)
      assert.is_nil(issue)

      -- Test valid removal line
      line, issue = validation._fix_hunk_content_line('-removed line', 3)
      assert.are.equal('-removed line', line)
      assert.is_nil(issue)

      -- Test empty line
      line, issue = validation._fix_hunk_content_line('', 4)
      assert.are.equal('', line)
      assert.is_nil(issue)
    end)

    it('should fix function definition lines missing context prefix', function()
      local validation = require 'vibe-coding.validation'

      local line, issue = validation._fix_hunk_content_line('def test_function():', 5)
      assert.are.equal(' def test_function():', line)
      assert.is_not_nil(issue)
      assert.are.equal('context_fix', issue.type)
      assert.are.equal('info', issue.severity)
      assert.string.matches(issue.message, 'Added missing space prefix for context line')
    end)

    it('should fix indented code lines missing context prefix', function()
      local validation = require 'vibe-coding.validation'

      local line, issue = validation._fix_hunk_content_line('    return True', 6)
      assert.are.equal('     return True', line)
      assert.is_not_nil(issue)
      assert.are.equal('context_fix', issue.type)
      assert.are.equal('info', issue.severity)
    end)

    it('should fix variable assignment lines missing context prefix', function()
      local validation = require 'vibe-coding.validation'

      local line, issue = validation._fix_hunk_content_line('mock_get_clusters.return_value = {', 7)
      assert.are.equal(' mock_get_clusters.return_value = {', line)
      assert.is_not_nil(issue)
      assert.are.equal('context_fix', issue.type)
    end)

    it('should fix bracket/parenthesis lines missing context prefix', function()
      local validation = require 'vibe-coding.validation'

      -- Test closing bracket
      local line, issue = validation._fix_hunk_content_line('}', 8)
      assert.are.equal(' }', line)
      assert.is_not_nil(issue)

      -- Test opening bracket
      line, issue = validation._fix_hunk_content_line('{', 9)
      assert.are.equal(' {', line)
      assert.is_not_nil(issue)

      -- Test closing parenthesis
      line, issue = validation._fix_hunk_content_line(')', 10)
      assert.are.equal(' )', line)
      assert.is_not_nil(issue)
    end)

    it('should fix string literals missing context prefix', function()
      local validation = require 'vibe-coding.validation'

      local line, issue = validation._fix_hunk_content_line('"cluster1": {"name": "test"}', 11)
      assert.are.equal(' "cluster1": {"name": "test"}', line)
      assert.is_not_nil(issue)

      line, issue = validation._fix_hunk_content_line("'single quoted string'", 12)
      assert.are.equal(" 'single quoted string'", line)
      assert.is_not_nil(issue)
    end)

    it('should NOT fix lines that start with special characters', function()
      local validation = require 'vibe-coding.validation'

      -- Test lines that should not be auto-fixed
      local special_chars = { '#', '@', '\\', '/', '*' }

      for _, char in ipairs(special_chars) do
        local test_line = char .. 'some content'
        local line, issue = validation._fix_hunk_content_line(test_line, 13)
        assert.are.equal(test_line, line)
        assert.is_not_nil(issue)
        assert.are.equal('invalid_line', issue.type)
        assert.are.equal('warning', issue.severity)
      end
    end)

    it('should NOT fix lines that contain addition/removal markers', function()
      local validation = require 'vibe-coding.validation'

      -- These could be legitimate content that happens to contain +/- characters
      local line, issue = validation._fix_hunk_content_line('  +something', 14)
      assert.are.equal('  +something', line)
      assert.is_not_nil(issue)
      assert.are.equal('invalid_line', issue.type)
    end)

    it('should truncate long lines in issue messages', function()
      local validation = require 'vibe-coding.validation'

      local long_line =
        'def very_long_function_name_that_exceeds_fifty_characters_and_should_be_truncated(param1, param2, param3)'
      local line, issue = validation._fix_hunk_content_line(long_line, 15)

      assert.are.equal(' ' .. long_line, line)
      assert.is_not_nil(issue)
      assert.string.matches(issue.message, '%.%.%.$') -- Should end with ...
      assert.is_true(#issue.message < #long_line + 50) -- Should be significantly shorter
    end)
  end)

  describe('validate_and_fix_diff integration', function()
    it('should fix multiple context lines in a complete diff', function()
      local validation = require 'vibe-coding.validation'

      local diff_with_missing_spaces = [[--- test.py
+++ test.py
@@ -1,5 +1,5 @@
def test_function():
    """Test docstring."""
    x = 1
-    old_line = 2
+    new_line = 2
    return x]]

      local fixed_diff, issues = validation.validate_and_fix_diff(diff_with_missing_spaces)

      -- Should have fixed the context lines
      assert.string.matches(fixed_diff, ' def test_function%(%):')
      assert.string.matches(fixed_diff, '     """Test docstring%."""')
      assert.string.matches(fixed_diff, '     x = 1')
      assert.string.matches(fixed_diff, '     return x')

      -- Should have several fix issues
      local context_fixes = 0
      for _, issue in ipairs(issues) do
        if issue.type == 'context_fix' then
          context_fixes = context_fixes + 1
        end
      end
      assert.is_true(context_fixes >= 4) -- At least 4 context lines fixed
    end)

    it('should handle mixed valid and invalid lines correctly', function()
      local validation = require 'vibe-coding.validation'

      local mixed_diff = [[--- test.py
+++ test.py
@@ -1,3 +1,3 @@
 valid_context_line
def missing_space_function():
+added_line
-removed_line
#invalid_comment_line]]

      local fixed_diff, issues = validation.validate_and_fix_diff(mixed_diff)

      -- Should fix the function definition
      assert.string.matches(fixed_diff, ' def missing_space_function%(%):')

      -- Should NOT fix the comment line (starts with #)
      assert.string.matches(fixed_diff, '#invalid_comment_line')

      -- Check issues
      local has_context_fix = false
      local has_invalid_line = false

      for _, issue in ipairs(issues) do
        if issue.type == 'context_fix' then
          has_context_fix = true
        elseif issue.type == 'invalid_line' then
          has_invalid_line = true
        end
      end

      assert.is_true(has_context_fix)
      assert.is_true(has_invalid_line)
    end)
  end)
end)
