return {
  name = 'Malformed Diff',
  description = 'Test error handling for malformed diff content',
  should_succeed = false,
  tags = { 'error', 'malformed', 'parse' },

  original_content = [[
line 1
line 2
line 3
]],

  diff_content = [[
This is not a valid diff
It's missing proper headers
And has no hunks]],

  expected_error_pattern = 'Could not parse file paths from diff header',
  file_path = 'test.txt',
}
