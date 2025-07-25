# Test Fixtures for VibeApplyPatch

This directory contains test fixtures for testing the `VibePatcher.apply_diff` function. Each fixture represents a complete test scenario with:

- Original file content
- Unified diff to apply
- Expected result after applying the diff
- Test metadata (description, expected success/failure)

## Structure

```
fixtures/
├── README.md                    # This file
├── fixture_loader.lua          # Fixture loading utilities
├── expected_to_pass/           # Tests expected to succeed
│   ├── simple/                 # Simple test cases
│   │   ├── basic_modification.lua
│   │   ├── line_addition.lua
│   │   └── line_removal.lua
│   ├── complex/                # Complex test cases
│   │   ├── multiple_hunks.lua
│   │   ├── context_matching.lua
│   │   └── edge_cases.lua
│   └── integration/            # Integration pipeline tests
│       ├── smart_validation_success.lua
│       ├── path_resolution_fix.lua
│       └── external_tool_fallback.lua
└── expected_to_fail/          # Tests expected to fail
    ├── missing_context.lua
    ├── malformed_diff.lua
    ├── validation_error_case.lua
    └── file_not_found.lua
```

## Fixture Format

Each fixture is a Lua file that returns a table with the following structure:

```lua
return {
  -- Test metadata
  name = "Human readable test name",
  description = "Detailed description of what this test validates",
  should_succeed = true, -- or false for error cases
  
  -- Test data (choose one of the three approaches below)
  
  -- Approach 1: Inline content (simple, works for most cases)
  original_content = "content of the original file",
  diff_content = "unified diff to apply",
  expected_content = "expected content after applying diff", -- only for successful cases
  expected_error_pattern = "expected error message pattern", -- only for error cases
  
  -- Approach 2: Convention-based external files (recommended for complex content)
  -- Creates files: {fixture_name}_original.txt, {fixture_name}_diff.txt, {fixture_name}_expected.txt
  -- Just omit the content fields above and they'll be loaded automatically
  
  -- Approach 3: Explicit external file paths (for custom naming)
  original_content_file = "custom_original.txt",
  diff_content_file = "custom_diff.txt", 
  expected_content_file = "custom_expected.txt", -- only for successful cases
  
  -- Optional metadata
  tags = { "basic", "modification" }, -- for categorizing tests
  file_path = "path/to/file.txt", -- target file path if different from default
}
```

### External File Loading

When fixture content contains characters that conflict with Lua syntax (like `[[` and `]]`), use external files:

**Convention-based (recommended):**
- Create files: `{fixture_name}_original.txt`, `{fixture_name}_diff.txt`, `{fixture_name}_expected.txt`
- Simply omit the content fields in the Lua file - they'll be loaded automatically

**Explicit file paths:**
- Use `original_content_file = "filename.txt"` to specify custom file names
- Explicit paths take priority over convention-based loading

## Usage in Tests

```lua
local fixtures = require('tests.fixtures.fixture_loader')

-- Load all fixtures
local all_fixtures = fixtures.load_all()

-- Load fixtures by category  
local simple_fixtures = fixtures.load_category('expected_to_pass/simple')
local integration_fixtures = fixtures.load_category('expected_to_pass/integration')
local error_fixtures = fixtures.load_category('expected_to_fail')

-- Load specific fixture
local fixture = fixtures.load_fixture('expected_to_pass/simple/basic_modification')

-- Create test cases
local basic_test = fixtures.create_test_case(fixture)  -- For basic diff application tests
local integration_test = fixtures.create_integration_test_case(fixture)  -- For full validation pipeline tests
```

## Integration Test Fixtures

The `integration/` category contains fixtures that test the complete validation and patch application pipeline, equivalent to running `VibeApplyPatch`. These fixtures test:

- **Smart validation**: Context line fixes, path resolution, etc.
- **Full validation pipeline**: All validation steps including external tool testing
- **Error handling**: Validation failures, parse errors, etc.
- **Options handling**: Silent mode, builtin engine forcing, etc.

Use `fixtures.create_integration_test_case(fixture)` for integration tests instead of the regular `create_test_case`.

## Adding New Fixtures

1. Create a new `.lua` file in the appropriate category directory
2. Follow the fixture format above
3. Run tests to ensure the fixture works correctly
4. Update this README if adding a new category