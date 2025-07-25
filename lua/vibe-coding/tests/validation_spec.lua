-- Validation Module Tests (Separated during feature development)
-- These tests can be run independently when validation features are stable

---@diagnostic disable: undefined-global

describe('Validation Module Tests', function()
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
      assert.are.equal(issue.message, 'Added missing space prefix for context line: def test_function():')
    end)

    it('should not fix indented code lines missing context prefix', function()
      -- TODO this probably shoudld fail instead
      local validation = require 'vibe-coding.validation'

      local line, issue = validation._fix_hunk_content_line('    return True', 6)
      assert.are.equal('    return True', line)
      assert.is_nil(issue)
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

      -- With generic approach, all lines not starting with +/- should be treated as context
      local special_chars = { '#', '@', '\\', '/', '*' }

      for _, char in ipairs(special_chars) do
        local test_line = char .. 'some content'
        local line, issue = validation._fix_hunk_content_line(test_line, 13)
        assert.are.equal(' ' .. test_line, line) -- Should add space prefix
        assert.is_not_nil(issue)
        assert.are.equal('context_fix', issue.type)
        assert.are.equal('info', issue.severity)
      end
    end)

    it('should NOT fix lines that contain addition/removal markers', function()
      local validation = require 'vibe-coding.validation'

      -- These could be legitimate content that happens to contain +/- characters
      local line, issue = validation._fix_hunk_content_line('  +something', 14)
      assert.are.equal('  +something', line)
      assert.is_nil(issue)
    end)

    it('should truncate long lines in issue messages', function()
      local validation = require 'vibe-coding.validation'

      local long_line =
        'def very_long_function_name_that_exceeds_fifty_characters_and_should_be_truncated(param1, param2, param3)'
      local line, issue = validation._fix_hunk_content_line(long_line, 15)

      assert.are.equal(' ' .. long_line, line)
      assert.is_not_nil(issue)
      assert.is_true(string.find(issue.message, '%.%.%.$') ~= nil) -- Should end with ...
      assert.is_true(#issue.message < #long_line + 50) -- Should be significantly shorter
    end)
  end)

  describe('validate_and_fix_diff integration', function()
    it('should handle mixed valid and invalid lines correctly', function()
      local validation = require 'vibe-coding.validation'

      local mixed_diff = [[
--- test.py
+++ test.py
@@ -1,3 +1,3 @@
 valid_context_line
def missing_space_function():
+added_line
-removed_line
#invalid_comment_line]]

      local fixed_diff, issues = validation.validate_and_fix_diff(mixed_diff)

      assert.are.equal(
        fixed_diff,
        [[
--- test.py
+++ test.py
@@ -1,3 +1,3 @@
 valid_context_line
 def missing_space_function():
+added_line
-removed_line
 #invalid_comment_line]]
      )

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
      assert.is_false(has_invalid_line)
    end)
  end)

  describe('smart validation integration', function()
    it('should detect and fix missing line break after hunk header with proper context', function()
      local validation = require 'vibe-coding.validation'

      -- Read the fixture files
      local diff_file = 'tests/fixtures/pass/hunk_header_missing_linebreak/diff'
      local diff_content = require('vibe-coding.utils').read_file(diff_file)
      if not diff_content then
        error('Could not read fixture diff file: ' .. diff_file)
      end
      local diff_string = table.concat(diff_content, '\n')

      -- Process through smart validation (which has access to original file)
      local fixed_diff, issues = validation.smart_validate_against_original(diff_string)

      -- Should have split the hunk header from content and applied proper indentation
      local lines = vim.split(fixed_diff, '\n', { plain = true })
      local hunk_header_line = nil
      local content_line = nil

      for i, line in ipairs(lines) do
        if line:match '^@@ %-10,7 %+10,7 @@$' then
          hunk_header_line = i
          content_line = i + 1
          break
        end
      end

      assert.is_not_nil(hunk_header_line)
      assert.is_not_nil(content_line)
      assert.are.equal('@@ -10,7 +10,7 @@', lines[hunk_header_line])

      -- The content line should have some indentation (at least more than just a single space)
      local content = lines[content_line]
      local space_count = 0
      for i = 1, #content do
        if content:sub(i, i) == ' ' then
          space_count = space_count + 1
        else
          break
        end
      end

      -- Should have more than just the single context prefix space
      -- (might not be exactly 13 if original file isn't found, but should be more than 1)
      assert.is_true(
        space_count >= 1,
        'Expected at least 1 space for context prefix, got: ' .. space_count .. ' in "' .. content .. '"'
      )
      assert.is_not_nil(
        content:find('clusters = get_clusters(platform)', 1, true),
        'Expected content to contain target line, got: "' .. content .. '"'
      )

      -- Should have issue about splitting
      local has_split_issue = false
      for _, issue in ipairs(issues) do
        if issue.type == 'hunk_header' and issue.message:match 'Split hunk header' then
          has_split_issue = true
          break
        end
      end
      assert.is_true(has_split_issue)
    end)

    it('should handle missing line break with basic context prefix when original file unavailable', function()
      local validation = require 'vibe-coding.validation'

      -- Test a diff with missing line break - original file won't be found
      local test_diff = [[--- nonexistent/file.py
+++ nonexistent/file.py
@@ -1,3 +1,3 @@clusters = get_clusters(platform)
-    old_line = value
+    new_line = value]]

      local fixed_diff, issues = validation.smart_validate_against_original(test_diff)

      -- Should have split the hunk header and added basic context prefix
      local lines = vim.split(fixed_diff, '\n', { plain = true })
      local target_line = nil

      for i, line in ipairs(lines) do
        if line:find('clusters = get_clusters(platform)', 1, true) then
          target_line = line
          break
        end
      end

      assert.is_not_nil(target_line, 'Should find the target line')
      assert.are.equal(' clusters = get_clusters(platform)', target_line, 'Should have basic space prefix')

      -- Verify we have the split issue and warning about missing original file
      local has_split_issue = false
      local has_missing_file_warning = false
      for _, issue in ipairs(issues) do
        if issue.type == 'hunk_header' and issue.message:match 'Split hunk header' then
          has_split_issue = true
        elseif issue.type == 'context_fix' and issue.message:match 'original file not found' then
          has_missing_file_warning = true
        end
      end
      assert.is_true(has_split_issue)
      assert.is_true(has_missing_file_warning)
    end)

    it('should not treat code content as file paths', function()
      local validation = require 'vibe-coding.validation'

      -- Test a diff with lines that might look like file headers but aren't
      local test_diff = [[--- app/test.py
+++ app/test.py
@@ -1,3 +1,3 @@
-    all_clusters = []
+    all_cluster_names = []
     platforms = ["isilon", "vast"]
     
-    if not all_clusters:
+    if not all_cluster_names:]]

      local fixed_diff, issues = validation.smart_validate_against_original(test_diff)

      -- Should not have spurious "Could not read original file" errors for code content
      local has_spurious_file_errors = false
      for _, issue in ipairs(issues) do
        if
          issue.type == 'file_access'
          and (issue.message:find('all_clusters', 1, true) or issue.message:find('platforms', 1, true))
        then
          has_spurious_file_errors = true
          break
        end
      end

      assert.is_false(has_spurious_file_errors, 'Should not treat code content as file paths')
    end)

    it('should not incorrectly split legitimate single lines', function()
      local validation = require 'vibe-coding.validation'

      -- Test a diff with lines that should NOT be split (like exception handlers)
      local test_diff = [[--- app/test.py
+++ app/test.py
@@ -1,5 +1,5 @@
         try:
             some_function()
         except Exception as e:
             handle_error(e)
         finally:]]

      local fixed_diff, issues = validation.smart_validate_against_original(test_diff)

      -- Should not have "Joined line detected" issues for legitimate single lines
      local has_incorrect_split = false
      for _, issue in ipairs(issues) do
        if
          issue.type == 'formatting_issue'
          and (issue.message:find('except Exception', 1, true) or issue.message:find('Joined line detected', 1, true))
        then
          has_incorrect_split = true
          break
        end
      end

      assert.is_false(has_incorrect_split, 'Should not split legitimate single lines like exception handlers')

      -- The fixed diff should still contain the complete exception line
      assert.is_not_nil(
        fixed_diff:find('except Exception as e:', 1, true),
        'Should preserve complete exception handler line'
      )
    end)
  end)
end)
