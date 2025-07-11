-- Fixture Summary and Utility Functions
-- This file provides utilities to summarize and analyze test fixtures

local M = {}

--- Generate a summary of all fixtures
-- @return table: Summary information about all fixtures
function M.generate_summary()
  local loader = require 'tests.fixtures.fixture_loader'
  local categories = loader.get_categories()
  local summary = {
    total_fixtures = 0,
    categories = {},
    by_tags = {},
    success_fixtures = 0,
    error_fixtures = 0,
  }

  for _, category in ipairs(categories) do
    local fixtures = loader.load_category(category)
    summary.categories[category] = {
      count = #fixtures,
      fixtures = {},
    }

    for _, fixture in ipairs(fixtures) do
      summary.total_fixtures = summary.total_fixtures + 1

      -- Count success vs error fixtures
      if fixture.should_succeed then
        summary.success_fixtures = summary.success_fixtures + 1
      else
        summary.error_fixtures = summary.error_fixtures + 1
      end

      -- Track tags
      if fixture.tags then
        for _, tag in ipairs(fixture.tags) do
          if not summary.by_tags[tag] then
            summary.by_tags[tag] = 0
          end
          summary.by_tags[tag] = summary.by_tags[tag] + 1
        end
      end

      -- Add fixture info
      table.insert(summary.categories[category].fixtures, {
        name = fixture.name,
        should_succeed = fixture.should_succeed,
        tags = fixture.tags or {},
      })
    end
  end

  return summary
end

--- Print a human-readable summary
function M.print_summary()
  local summary = M.generate_summary()

  print '=== Test Fixture Summary ==='
  print(string.format('Total fixtures: %d', summary.total_fixtures))
  print(string.format('Success cases: %d', summary.success_fixtures))
  print(string.format('Error cases: %d', summary.error_fixtures))
  print()

  print 'By Category:'
  for category, info in pairs(summary.categories) do
    print(string.format('  %s: %d fixtures', category, info.count))
    for _, fixture in ipairs(info.fixtures) do
      local status = fixture.should_succeed and '✓' or '✗'
      local tags_str = table.concat(fixture.tags, ', ')
      print(string.format('    %s %s [%s]', status, fixture.name, tags_str))
    end
  end
  print()

  print 'By Tags:'
  for tag, count in pairs(summary.by_tags) do
    print(string.format('  %s: %d fixtures', tag, count))
  end
end

return M
