return {
  name = 'External File Test',
  description = 'Test case using explicit external files to avoid Lua syntax conflicts with [[ ]]',
  should_succeed = true,
  tags = { 'simple', 'external' },

  -- Explicit external file loading (alternative to convention-based)
  original_content_file = 'external_file_test_original.txt',
  diff_content_file = 'external_file_test_diff.txt',
  expected_content_file = 'external_file_test_expected.txt',

  file_path = 'test.js',
}