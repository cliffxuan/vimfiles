return {
  name = 'Path Resolution - Auto Fix Relative Paths',
  description = 'Test that path resolution automatically fixes relative paths to absolute paths',
  should_succeed = true,
  tags = { 'integration', 'path_resolution', 'validation' },

  file_path = 'utils.lua', -- This will be resolved during validation
}
