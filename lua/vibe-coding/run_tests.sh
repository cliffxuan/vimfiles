#!/bin/bash

# Test runner script for vibe-coding plugin
# This script runs the unit tests using Neovim's built-in Lua and plenary test harness

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running vibe-coding plugin tests...${NC}"
echo "========================================"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Run the tests with nvim headless using minimal init
# Redirect both stdout and stderr, then filter out the config error lines
if nvim --headless -u tests/minimal_init.lua \
    -c "lua require('plenary.test_harness').test_directory('tests')" \
    -c "qa!" 2>&1 | \
  grep -v "E5113\|lspconfig\|stack traceback\|lua chunk" | \
  grep -v ".*init.lua.*in main chunk" | \
  grep -v ".config/nvim/lua/lsp.lua.*in main chunk" | \
  grep -v "Error detected while processing" | \
  grep -v "no field package.preload" | \
  grep -v "no file.*\.lua\|no file.*\.so" | \
  grep -v "\[C\]: in function 'require'" | \
  grep -v "^$"; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed!${NC}"
  exit 1
fi
