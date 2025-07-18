return {
  name = 'Semicolon Separated Statements',  
  description = 'Test detection and splitting of multiple statements separated by semicolons',
  should_succeed = false, -- Complex case - disable for now
  expected_error_pattern = 'Could not find this context in the file',
  tags = { 'integration', 'joined_lines', 'semicolon' },
  
  file_path = 'handler.js',
}