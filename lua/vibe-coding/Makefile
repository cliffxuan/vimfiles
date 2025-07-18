.PHONY: test test-verbose clean help

# Default target
help:
@echo "Available targets:"
@echo "  test         - Run all tests"
@echo "  test-verbose - Run tests with verbose output"
@echo "  clean        - Clean up test artifacts"
@echo "  help         - Show this help message"

# Run tests
test:
@./run_tests.sh

# Run tests with verbose output (shows stderr)
test-verbose:
@echo "Running vibe-coding plugin tests (verbose)..."
@echo "========================================"
nvim --headless -c "lua require('plenary.test_harness').test_directory('tests')" -c "qa!"

# Clean up any test artifacts
clean:
@echo "Cleaning up test artifacts..."
@find . -name "*.tmp" -delete 2>/dev/null || true
@find . -name "*.log" -delete 2>/dev/null || true
@echo "Clean complete."

# Run a specific test by name (usage: make test-filter FILTER="test_name")
test-filter:
@if [ -z "$(FILTER)" ]; then \
echo "Usage: make test-filter FILTER='test_name'"; \
exit 1; \
fi
@echo "Running tests matching: $(FILTER)"
nvim --headless -c "lua require('plenary.test_harness').test_directory('tests', { minimal_init = 'tests/minimal_init.lua' })" -c "qa!" | grep -i "$(FILTER)" || echo "No tests matched filter: $(FILTER)"
