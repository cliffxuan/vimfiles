#!/bin/bash

# Test runner script for vibe-coding plugin
# This script runs the unit tests using Neovim's built-in Lua and plenary test harness

set -e

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
TEST_PATTERN=""

while [[ $# -gt 0 ]]; do
  case $1 in
  -t | --test)
    TEST_PATTERN="$2"
    shift 2
    ;;
  -h | --help)
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --test PATTERN    Run tests matching PATTERN"
    echo "  -h, --help           Show this help message"
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

echo -e "${YELLOW}Running vibe-coding plugin tests...${NC}"
echo "========================================"

# Get the directory where this script is located (tests directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Change to parent directory (main plugin directory)
cd "$SCRIPT_DIR/.."

# Create a temporary file to capture test output
TEMP_OUTPUT=$(mktemp)
trap 'rm -f "$TEMP_OUTPUT"' EXIT

# Function to run tests with pattern filtering
run_tests() {
  local test_cmd="$1"
  nvim --headless -c "$test_cmd" -c "qa!" 2>&1
}

# Build and execute the test command based on pattern
if [[ -n "$TEST_PATTERN" ]]; then
  echo "Running tests matching pattern: $TEST_PATTERN"
  echo "========================================"

  # Find test files matching the pattern
  MATCHING_FILES=()
  while IFS= read -r -d '' file; do
    MATCHING_FILES+=("$file")
  done < <(find tests -name "*_spec.lua" \( -path "*${TEST_PATTERN}*" -o -name "*${TEST_PATTERN}*" \) -print0)

  if [[ ${#MATCHING_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}No test files matching pattern: $TEST_PATTERN${NC}"
    exit 1
  fi

  echo "Found ${#MATCHING_FILES[@]} matching test file(s):"
  for file in "${MATCHING_FILES[@]}"; do
    echo "  - $file"
  done
  echo "========================================"

  # Run each matching file and combine output
  {
    for test_file in "${MATCHING_FILES[@]}"; do
      echo "Testing: 	$test_file	"
      run_tests "lua require('plenary.test_harness').test_file('$test_file')"
    done
  }
else
  # Run all tests in directory
  run_tests "lua require('plenary.test_harness').test_directory('tests', { sequential = true })"
fi |
  awk '
    BEGIN { in_error_block = 0 }
    
    # Start of error block detection
    /^Error detected while processing/ {
      in_error_block = 1
      next
    }
    
    # End of error block detection - when we see stack traceback, skip a few more lines then reset
    /stack traceback:/ {
      if (in_error_block) {
        stack_lines = 0
        next
      }
    }
    
    # Skip lines that are clearly part of error context
    in_error_block && (/^E[0-9]+:/ || /^\s*no field/ || /^\s*no file/ || /^\s*\[C\]:/ || /\/.*\.lua:[0-9]+:/) {
      next
    }
    
    # Reset error block state when we encounter normal output patterns
    /^(Starting\.\.\.|Scheduling:|Testing:|\[3[0-9]m|Success:|Failed|Errors)/ {
      in_error_block = 0
    }
    
    # Print line if not in error block
    !in_error_block { print }
  ' | tee "$TEMP_OUTPUT"
echo ""
echo "========================================"
echo -e "${BLUE}TEST RESULTS SUMMARY${NC}"
echo "========================================"

# Parse the output to extract statistics
TOTAL_SUCCESS=0
TOTAL_FAILED=0
TOTAL_ERRORS=0
SPECS_RUN=0

# Count results from each spec file
while IFS= read -r line; do
  # Remove ANSI color codes for easier pattern matching
  clean_line=$(printf '%s\n' "$line" | sed 's/\x1b\[[0-9;]*m//g')

  # Look for success count patterns like "Success: 	21"
  if [[ $clean_line =~ Success:[[:space:]]*([0-9]+) ]]; then
    SUCCESS=${BASH_REMATCH[1]}
    TOTAL_SUCCESS=$((TOTAL_SUCCESS + SUCCESS))
    SPECS_RUN=$((SPECS_RUN + 1))
  fi

  # Look for failed count patterns like "Failed : 	0"
  if [[ $clean_line =~ Failed[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
    FAILED=${BASH_REMATCH[1]}
    TOTAL_FAILED=$((TOTAL_FAILED + FAILED))
  fi

  # Look for error count patterns like "Errors : 	0"
  if [[ $clean_line =~ Errors[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
    ERRORS=${BASH_REMATCH[1]}
    TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
  fi
done <"$TEMP_OUTPUT"

# Display summary
echo "Spec files run: $SPECS_RUN"
echo -e "${GREEN}Total Success: $TOTAL_SUCCESS${NC}"

if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo -e "${RED}Total Failed:  $TOTAL_FAILED${NC}"
fi

if [[ $TOTAL_ERRORS -gt 0 ]]; then
  echo -e "${RED}Total Errors:  $TOTAL_ERRORS${NC}"
fi

TOTAL_TESTS=$((TOTAL_SUCCESS + TOTAL_FAILED + TOTAL_ERRORS))
echo "Total Tests:   $TOTAL_TESTS"

# Calculate success rate
if [[ $TOTAL_TESTS -gt 0 ]]; then
  SUCCESS_RATE=$((TOTAL_SUCCESS * 100 / TOTAL_TESTS))
  echo "Success Rate:  ${SUCCESS_RATE}%"
fi

echo "========================================"

# Overall result
if [[ $TOTAL_FAILED -eq 0 && $TOTAL_ERRORS -eq 0 && $TOTAL_SUCCESS -gt 0 ]]; then
  echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
  exit 0
elif [[ $TOTAL_FAILED -gt 0 || $TOTAL_ERRORS -gt 0 ]]; then
  echo -e "${RED}✗ SOME TESTS FAILED${NC}"
  exit 1
else
  echo -e "${RED}✗ NO TESTS RUN${NC}"
  exit 1
fi
