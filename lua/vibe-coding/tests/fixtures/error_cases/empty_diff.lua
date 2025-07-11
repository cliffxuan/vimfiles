return {
  name = 'Empty Diff',
  description = 'Test error handling for diff with no content',
  should_succeed = false,
  tags = { 'error', 'empty' },

  original_content = [[some content]],

  diff_content = [[]],

  expected_error_pattern = 'Diff content is too short to be valid%.',
  file_path = 'test.txt',
}
