return {
  name = 'Validation Error - Missing Context Lines',
  description = 'Test that validation fails when context lines are completely wrong and cannot be fixed',
  should_succeed = false,
  expected_error_pattern = 'Could not find this context in the file',
  tags = { 'integration', 'validation', 'error' },
  
  file_path = 'broken.js',
}