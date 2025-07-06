-- lua/tests/vibe-coding_spec.lua

-- Note: The plugin code needs to be accessible.
-- For a single-file plugin, you might need to load it manually in your test setup.

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
        assert.are.equal(2, #parsed.hunks[1].lines)
        assert.are.equal('-local b = 2 -- remove', parsed.hunks[1].lines[1])
        assert.are.equal('+local b = 3 -- add', parsed.hunks[1].lines[2])
      end)
    end)

    describe('apply_diff function', function()
      it('should apply a modification hunk to a file', function()
        local original_content = 'line1\nline2_to_remove\nline3'
        local expected_content = { 'line1', 'line2_to_add', 'line3' }
        local parsed_diff = {
          old_path = 'file.txt',
          new_path = 'file.txt',
          hunks = {
            { lines = { '-line2_to_remove', '+line2_to_add' } },
          },
        }

        mock(vibe.FileCache, 'get_content', function()
          return original_content, nil
        end)

        -- 1. Create a spy that has the behavior of our mock
        local write_spy = spy.new(function()
          return true, nil
        end)

        -- 2. Place the spy into the Utils table using mock()
        mock(vibe.Utils, 'write_file', write_spy)

        -- Call the function we are testing
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)

        assert.is_true(success)
        assert.string.matches(msg, 'Applied 1 hunks to file.txt')

        -- 3. Now, you can make assertions on the spy object itself
        assert.spy(write_spy).was.called(1)
        assert.spy(write_spy).was.called_with('file.txt', expected_content)
      end)

      it('should create a new file when old_path is /dev/null', function()
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
        local write_spy = spy.new(function()
          return true, nil
        end)
        mock(vibe.Utils, 'write_file', write_spy)
        local success, msg = vibe.VibePatcher.apply_diff(parsed_diff)
        assert.is_true(success)
        assert.string.matches(msg, 'Applied 1 hunks to new_file.txt')
        assert.spy(write_spy).was.called(1)
        assert.spy(write_spy).was.called_with('new_file.txt', expected_content)
      end)
    end)
  end)

  -- =============================================================================
  --  VibeDiff Module Tests
  -- =============================================================================
  describe('VibeDiff Module', function()
    describe('extract_code_blocks', function()
      it('should extract a single code block', function()
        local content = 'Some text\n```lua\nlocal a = 1\n```\nmore text'
        local blocks = vibe.VibeDiff.extract_code_blocks(content)
        assert.are.equal(1, #blocks)
        assert.are.equal('lua', blocks[1].language)
        assert.are.equal('local a = 1', blocks[1].content_str)
      end)

      it('should extract multiple code blocks', function()
        local content = '```python\nprint("hi")\n```\n\n```\nraw text\n```'
        local blocks = vibe.VibeDiff.extract_code_blocks(content)
        assert.are.equal(2, #blocks)
        assert.are.equal('python', blocks[1].language)
        assert.is_nil(blocks[2].language)
        assert.are.equal('raw text', blocks[2].content_str)
      end)

      it('should handle incomplete code blocks gracefully', function()
        local content = 'Here is some code:\n```javascript\nconst x = 10;'
        local blocks = vibe.VibeDiff.extract_code_blocks(content)
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
