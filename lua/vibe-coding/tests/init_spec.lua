-- lua/tests/vibe-coding_spec.lua

-- Note: The plugin code needs to be accessible.
-- For a single-file plugin, you might need to load it manually in your test setup.

---@diagnostic disable: undefined-global

describe('Vibe-Coding Plugin Unit Tests', function()
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

  -- =============================================================================
  --  Utils Module Tests
  -- =============================================================================
  describe('Utils Module', function()
    describe('JSON functions', function()
      it('should encode a Lua table to a JSON string', function()
        local original_data = { key = 'value', number = 123 }
        local json_str, err = vibe.Utils.json_encode(original_data)

        -- 1. Ensure the encoding process didn't produce an error
        assert.is_nil(err)
        assert.is_string(json_str)

        -- 2. Decode the result back into a Lua table
        local decoded_data, decode_err = vibe.Utils.json_decode(json_str)
        assert.is_nil(decode_err)

        -- 3. Compare the decoded table to the original.
        -- `are.same` performs a deep comparison of the tables.
        assert.are.same(original_data, decoded_data)
      end)
      it('should decode a JSON string to a Lua table', function()
        local json_str = '{"key":"value","number":123}'
        local data, err = vibe.Utils.json_decode(json_str)
        assert.is_nil(err)
        assert.are.same({ key = 'value', number = 123 }, data)
      end)
    end)

    describe('path_relative function', function()
      it('should return "." for identical paths', function()
        assert.are.equal('.', vibe.Utils.path_relative('/a/b/c', '/a/b/c'))
      end)

      it('should compute relative path to a child directory', function()
        assert.are.equal('d/e', vibe.Utils.path_relative('/a/b/c', '/a/b/c/d/e'))
      end)

      it('should compute relative path to a parent directory', function()
        assert.are.equal('../..', vibe.Utils.path_relative('/a/b/c/d', '/a/b'))
      end)

      it('should compute relative path to a sibling directory', function()
        assert.are.equal('../d/e', vibe.Utils.path_relative('/a/b/c', '/a/b/d/e'))
      end)
    end)
  end)

  -- =============================================================================
  --  VibePatcher Module Tests
  -- =============================================================================
  describe('VibePatcher Module', function()
    -- Helper function to setup manual mocking
    local function setup_file_mocks(read_content, write_result)
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
    local spy = require 'luassert.spy'

    describe('parse_diff function', function()
      local diff_text = [[
--- a/file.lua
+++ b/file.lua
@@ -1,5 +1,5 @@
 local a = 1
-local b = 2 -- remove
+local b = 3 -- add
 local c = 4
 local d = 5
 local e = 6
]]
      it('should parse a valid unified diff block', function()
        local parsed, err = vibe.VibePatcher.parse_diff(diff_text)
        assert.is_nil(err)
        assert.are.equal('file.lua', parsed.old_path)
        assert.are.equal('file.lua', parsed.new_path)
        assert.are.equal(1, #parsed.hunks)
        assert.are.equal(6, #parsed.hunks[1].lines)
        assert.are.equal(' local a = 1', parsed.hunks[1].lines[1])
        assert.are.equal('-local b = 2 -- remove', parsed.hunks[1].lines[2])
        assert.are.equal('+local b = 3 -- add', parsed.hunks[1].lines[3])
        assert.are.equal(' local c = 4', parsed.hunks[1].lines[4])
        assert.are.equal(' local d = 5', parsed.hunks[1].lines[5])
        assert.are.equal(' local e = 6', parsed.hunks[1].lines[6])
      end)
    end)

    describe('apply_diff function', function()
      -- This test now includes a shared context line ('line1'), which is more realistic
      -- and helps verify the patching logic more accurately.
      it('should apply a modification hunk to a file', function()
        local original_content = 'line1\nline2_to_remove\nline3'
        local mocks = setup_file_mocks(original_content)

        -- Test Data
        local expected_content = { 'line1', 'line2_to_add', 'line3' }
        local parsed_diff = {
          old_path = 'file.txt',
          new_path = 'file.txt',
          hunks = {
            { lines = { '-line2_to_remove', '+line2_to_add' } },
          },
        }

        -- Execution
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        -- Assertions
        assert.is_true(success, 'Expected apply_diff to succeed')
        assert.string.matches(msg, 'Successfully applied 1 hunks to file.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('file.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      it('should create a new file when old_path is /dev/null', function()
        local mocks = setup_file_mocks()

        local parsed_diff = {
          old_path = '/dev/null',
          new_path = 'new_file.txt',
          hunks = {
            { lines = { '+new file line 1', '+new file line 2' } },
          },
        }
        local expected_content = {
          'new file line 1',
          'new file line 2',
        }
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)
        assert.is_true(success)
        assert.string.matches(msg, 'Successfully applied 1 hunks to new_file.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('new_file.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      -- This test now correctly expects the output after applying both hunks in sequence.
      it('should apply a patch with multiple hunks correctly', function()
        local mocks = setup_file_mocks('a\nb\nc\nd\ne')

        local parsed_diff = {
          old_path = 'test.txt',
          new_path = 'test.txt',
          hunks = {
            { lines = { ' a', '-b', '+B', ' c' } },
            { lines = { ' c', '-d', '+D', ' e' } },
          },
        }
        local expected_content = { 'a', 'B', 'c', 'D', 'e' }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success, 'Expected multi-hunk apply to succeed')
        assert.string.matches(msg, 'Successfully applied 2 hunks to test.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('test.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      -- This test now asserts the exact, detailed error message for better diagnostics.
      it('should return a detailed error if a hunk context cannot be found', function()
        local mocks = setup_file_mocks('line1\nline2\nline3')

        local hunk_lines = { '-nonexistent line', '+a new line' }
        local parsed_diff = {
          old_path = 'test.lua',
          new_path = 'test.lua',
          hunks = { { lines = hunk_lines } },
        }
        local expected_error_msg = 'Failed to apply hunk #1 to test.lua.\n'
          .. 'Hunk content:\n'
          .. table.concat(hunk_lines, '\n')
          .. '\n\n'
          .. 'Searching for pattern:\n'
          .. 'nonexistent line'
          .. '\n\n'
          .. 'Could not find this context in the file.'

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_false(success, 'Expected apply_diff to fail')
        assert.are.equal(expected_error_msg, msg)
        assert.are.equal(0, #mocks.write_calls, 'Expected write_file to not be called')
        
        mocks.restore()
      end)

      it('should skip file deletion when new_path is /dev/null', function()
        local mocks = setup_file_mocks()

        local parsed_diff = {
          old_path = 'file_to_delete.txt',
          new_path = '/dev/null',
          hunks = {
            { lines = { '-line1' } },
          },
        }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success)
        assert.are.equal('Skipped file deletion for file_to_delete.txt', msg)
        assert.are.equal(0, #mocks.write_calls, 'Expected write_file to not be called')
        
        mocks.restore()
      end)

      it('should handle context lines before and after changes correctly', function()
        local original_content = [[@allocation_router.put(
    "/{cluster}/{name}",
    response_model=Allocation,
    dependencies=[Depends(check_operator_permission)],
)
def update_allocation(cluster: str, name: str, allocation: Allocation):
    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"
    data: str | None = redis_client.get(key)  # type: ignore]]

        local mocks = setup_file_mocks(original_content)

        -- This represents the problematic diff from the original issue
        local parsed_diff = {
          old_path = 'app/api/v2/routes.py',
          new_path = 'app/api/v2/routes.py',
          hunks = {
            {
              lines = {
                ' @allocation_router.put(',
                '     "/{cluster}/{name}",',
                '     response_model=Allocation,',
                '     dependencies=[Depends(check_operator_permission)],',
                ' )',
                '-def update_allocation(cluster: str, name: str, allocation: Allocation):',
                '+def update_allocation(cluster: str, name: str, allocation: str):',
                '     key = f"{REDIS_PREFIX}:share:{cluster}:{name}"',
                '     data: str | None = redis_client.get(key)  # type: ignore',
              },
            },
          },
        }

        local expected_content_lines = {
          '@allocation_router.put(',
          '    "/{cluster}/{name}",',
          '    response_model=Allocation,',
          '    dependencies=[Depends(check_operator_permission)],',
          ')',
          'def update_allocation(cluster: str, name: str, allocation: str):',
          '    key = f"{REDIS_PREFIX}:share:{cluster}:{name}"',
          '    data: str | None = redis_client.get(key)  # type: ignore',
        }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success, 'Expected apply_diff to succeed with context lines')
        assert.string.matches(msg, 'Successfully applied 1 hunks to app/api/v2/routes.py')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('app/api/v2/routes.py', mocks.write_calls[1].filepath)
        assert.are.same(expected_content_lines, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      it('should handle multiple context sections in a single hunk', function()
        -- Test case with context before changes, changes, and context after changes
        local original_content = 'line1\nline2\nold_line\nline4\nline5'

        local mocks = setup_file_mocks(original_content)

        local parsed_diff = {
          old_path = 'test.txt',
          new_path = 'test.txt',
          hunks = {
            {
              lines = {
                ' line1',
                ' line2',
                '-old_line',
                '+new_line',
                ' line4',
                ' line5',
              },
            },
          },
        }

        local expected_content = { 'line1', 'line2', 'new_line', 'line4', 'line5' }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success, 'Expected apply_diff to succeed with context before and after')
        assert.string.matches(msg, 'Successfully applied 1 hunks to test.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('test.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      it('should handle hunks with only context before changes', function()
        local original_content = 'context1\ncontext2\nold_line'

        local mocks = setup_file_mocks(original_content)

        local parsed_diff = {
          old_path = 'test.txt',
          new_path = 'test.txt',
          hunks = {
            {
              lines = {
                ' context1',
                ' context2',
                '-old_line',
                '+new_line',
              },
            },
          },
        }

        local expected_content = { 'context1', 'context2', 'new_line' }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success, 'Expected apply_diff to succeed with context before only')
        assert.string.matches(msg, 'Successfully applied 1 hunks to test.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('test.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      it('should handle hunks with only context after changes', function()
        local original_content = 'old_line\ncontext1\ncontext2'

        local mocks = setup_file_mocks(original_content)

        local parsed_diff = {
          old_path = 'test.txt',
          new_path = 'test.txt',
          hunks = {
            {
              lines = {
                '-old_line',
                '+new_line',
                ' context1',
                ' context2',
              },
            },
          },
        }

        local expected_content = { 'new_line', 'context1', 'context2' }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success, 'Expected apply_diff to succeed with context after only')
        assert.string.matches(msg, 'Successfully applied 1 hunks to test.txt')
        assert.are.equal(1, #mocks.write_calls, 'Expected write_file to be called once')
        assert.are.equal('test.txt', mocks.write_calls[1].filepath)
        assert.are.same(expected_content, mocks.write_calls[1].content)
        
        mocks.restore()
      end)

      it('should fail properly when hunk cannot be applied instead of falsely claiming success', function()
        -- This test verifies the bug fix where hunks that couldn't be applied
        -- would still report success
        local original_content = 'unrelated_line1\nunrelated_line2\nunrelated_line3'

        local mocks = setup_file_mocks(original_content)

        -- This diff has lines to add AND remove, but the pattern won't match the file
        local parsed_diff = {
          old_path = 'test.txt',
          new_path = 'test.txt',
          hunks = {
            {
              lines = {
                '-def update_allocation(cluster: str, name: str, allocation: Allocation):',
                '+def update_allocation(cluster: str, name: str, allocation: str):',
              },
            },
          },
        }

        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        -- Should fail instead of falsely claiming success
        assert.is_false(success, 'Expected apply_diff to fail when hunk cannot be found')
        local expected_error_msg = 'Failed to apply hunk #1 to test.txt.\n'
          .. 'Hunk content:\n'
          .. '-def update_allocation(cluster: str, name: str, allocation: Allocation):\n'
          .. '+def update_allocation(cluster: str, name: str, allocation: str):\n'
          .. '\n'
          .. 'Searching for pattern:\n'
          .. 'def update_allocation(cluster: str, name: str, allocation: Allocation):\n'
          .. '\n'
          .. 'Could not find this context in the file.'
        assert.are.equal(expected_error_msg, msg)
        assert.are.equal(0, #mocks.write_calls, 'Expected write_file to not be called')
        
        mocks.restore()
      end)
    end)

    -- =============================================================================
    --  VibePatcher Fixture-Based Tests
    -- =============================================================================
    describe('Fixture-based tests', function()
      local fixtures = require('tests.fixtures.fixture_loader')
      
      -- Load all fixtures and create tests
      local all_fixtures = fixtures.load_all()
      
      for _, fixture in ipairs(all_fixtures) do
        it(fixture.name, fixtures.create_test_case(fixture))
      end
    end)
  end)

  -- =============================================================================
  --  VibeDiff Module Tests
  -- =============================================================================
  describe('VibeDiff Module', function()
    describe('extract_code_blocks', function()
      it('should extract a single code block', function()
        local content = 'Some text\n```lua\nlocal a = 1\n```\nmore text'
        local blocks = vibe.VibePatcher.extract_code_blocks(content)
        assert.are.equal(1, #blocks)
        assert.are.equal('lua', blocks[1].language)
        assert.are.equal('local a = 1', blocks[1].content_str)
      end)

      it('should extract multiple code blocks', function()
        local content = '```python\nprint("hi")\n```\n\n```\nraw text\n```'
        local blocks = vibe.VibePatcher.extract_code_blocks(content)
        assert.are.equal(2, #blocks)
        assert.are.equal('python', blocks[1].language)
        assert.is_nil(blocks[2].language)
        assert.are.equal('raw text', blocks[2].content_str)
      end)

      it('should handle incomplete code blocks gracefully', function()
        local content = 'Here is some code:\n```javascript\nconst x = 10;'
        local blocks = vibe.VibePatcher.extract_code_blocks(content)
        assert.are.equal(1, #blocks)
        local expected_lines = {
          'const x = 10;',
          '-- [INCOMPLETE CODE BLOCK]',
        }
        local actual_lines = vim.split(blocks[1].content_str, '\n')
        assert.are.same(expected_lines, actual_lines)
      end)
    end)
  end)
end)
