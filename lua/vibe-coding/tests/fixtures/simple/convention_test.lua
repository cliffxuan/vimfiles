return {
  name = 'Convention-Based External Files',
  description = 'Test automatic loading of external files using naming conventions: {fixture_name}_{content_type}.txt',
  should_succeed = true,
  tags = { 'simple', 'convention', 'external' },

  -- No explicit file paths - uses convention: convention_test_{original,diff,expected}.txt

  file_path = 'process.js',
}
