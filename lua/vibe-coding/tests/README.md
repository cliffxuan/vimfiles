# Vibe-Coding Plugin Tests

This directory contains unit tests for the vibe-coding Neovim plugin.

## Running Tests

### Using the test script (recommended)
```bash
./run_tests.sh
```

### Using Make
```bash
make test          # Run all tests
make test-verbose  # Run tests with verbose output
make help          # Show available targets
```

### Manual execution
```bash
nvim --headless -u tests/minimal_init.lua -c "lua require('plenary.test_harness').test_directory('tests')" -c "qa!"
```

## Test Structure

The tests are organized into the following modules:

- **Utils Module Tests**: JSON encoding/decoding and path utilities
- **VibePatcher Module Tests**: Diff parsing and applying functionality
- **VibeDiff Module Tests**: Code block extraction

## Requirements

- Neovim with Lua support
- plenary.nvim plugin (for test harness)
- luassert (for assertions and mocking)

## Test Files

- `init_spec.lua` - Main test file containing all test cases
- `minimal_init.lua` - Minimal Neovim configuration for running tests
- `README.md` - This file

## Adding New Tests

To add new tests, follow the existing pattern in `init_spec.lua`:

```lua
describe('Your Module', function()
  it('should do something', function()
    -- Test code here
    assert.are.equal(expected, actual)
  end)
end)
```

## Mocking

The tests use luassert mocking to isolate functionality:

```lua
mock(vibe.Utils, 'write_file', function()
  return true, nil
end)
```

This ensures tests don't actually write to the filesystem or make external calls.