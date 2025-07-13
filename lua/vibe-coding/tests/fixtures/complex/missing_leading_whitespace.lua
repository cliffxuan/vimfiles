return {
  name = 'Missing Leading Whitespace Context Lines',
  description = 'Test case for handling context lines that are missing the leading space in diff format',
  -- should_succeed = true,
  should_succeed = false,
  tags = { 'whitespace', 'context-lines', 'robustness' },
  expected_error_pattern = "",
  file_path = 'scripts/bao',
}
