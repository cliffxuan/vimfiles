#!/bin/bash

# Test runner script for vibe-coding plugin
# This script runs the unit tests using Neovim's built-in Lua and plenary test harness

set -e

# Colors for output
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running vibe-coding plugin tests...${NC}"
echo "========================================"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Run the tests with nvim headless using minimal init
nvim --headless \
  -c "lua require('plenary.test_harness').test_directory('tests')" \
  -c "qa!"
