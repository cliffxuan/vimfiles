return {
  name = 'Dictionary Replacement Content Validation',
  description = 'Enhanced test that validates old content is completely removed and new content appears exactly once, with empty line preservation',
  should_succeed = true,
  tags = { 'complex', 'dictionary', 'replacement', 'validation', 'empty-lines' },

  file_path = 'test.py',
  
  -- Custom validation function to ensure proper replacement behavior
  custom_validation = function(result_content, fixture)
    local lines = type(result_content) == 'table' and result_content or vim.split(result_content, '\n', { plain = true, trimempty = false })
    
    -- Verify that old content was replaced, not duplicated
    local old_pattern_count = 0
    local new_pattern_count = 0

    for _, line in ipairs(lines) do
      if line:match('"cluster1": {"name": "cluster1", "platform": "vast"}') and not line:match('"state": "LIVE"') then
        old_pattern_count = old_pattern_count + 1
      end
      if line:match('"cluster1": {"name": "cluster1", "platform": "vast", "state": "LIVE"}') then
        new_pattern_count = new_pattern_count + 1
      end
    end

    assert.are.equal(0, old_pattern_count, 'Old dictionary entries should be completely removed')
    assert.are.equal(1, new_pattern_count, 'New dictionary entries should be present exactly once')
    
    -- Verify empty lines are preserved (should have empty lines at specific positions)
    local empty_line_positions = {}
    for i, line in ipairs(lines) do
      if line == '' then
        table.insert(empty_line_positions, i)
      end
    end
    
    assert.is_true(#empty_line_positions >= 2, 'Should preserve at least 2 empty lines')
    
    return true
  end,
}