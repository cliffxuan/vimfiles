-- Fixtures V2 Test Suite
-- Tests for the new language-agnostic fixture system

---@diagnostic disable: undefined-global

describe('Fixtures V2 System', function()
  local fixtures

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

    -- Add current test directory to package.path for relative requires
    local current_dir = debug.getinfo(1, 'S').source:match '@(.*/)' or './'
    local original_path = package.path
    package.path = current_dir .. '?.lua;' .. current_dir .. '?/init.lua;' .. package.path
    fixtures = require 'fixtures.fixture_loader_v2'
    package.path = original_path
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

  describe('Fixture Loading', function()
    it('should load a single fixture', function()
      local test_fixture = fixtures.load_fixture 'pass/line_addition'
      assert.is_string(test_fixture.name)
      assert.are.equal('Line Addition', test_fixture.name)
      assert.is_string(test_fixture.original_content)
      assert.is_string(test_fixture.diff_content)
    end)

    it('should load pass category fixtures', function()
      local pass_fixtures = fixtures.load_category 'pass'
      assert.is_true(#pass_fixtures > 0, 'Should have pass fixtures')
      assert.are.equal(37, #pass_fixtures)
    end)

    it('should load fail category fixtures', function()
      local fail_fixtures = fixtures.load_category 'fail'
      assert.is_true(#fail_fixtures > 0, 'Should have fail fixtures')
      assert.are.equal(7, #fail_fixtures)
    end)
    it('should load all fixtures', function()
      local all_fixtures = fixtures.load_all()
      assert.are.equal(44, #all_fixtures)
    end)
  end)

  describe('Fixture Test Case Creation', function()
    it('should create test cases for pass fixtures', function()
      local pass_fixtures = fixtures.load_category 'pass'

      for _, fixture in ipairs(pass_fixtures) do
        it(fixture.name, fixtures.create_integration_test_case(fixture))
      end
    end)

    it('should create test cases for fail fixtures', function()
      local fail_fixtures = fixtures.load_category 'fail'

      for _, fixture in ipairs(fail_fixtures) do
        it(fixture.name, fixtures.create_integration_test_case(fixture))
      end
    end)
  end)
end)
