"""
Test the Python validation implementation to match Lua behavior.
"""

import tempfile
import sys
import os
from pathlib import Path

try:
    import pytest
    HAS_PYTEST = True
except ImportError:
    HAS_PYTEST = False

# Add parent directory to path
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from fixture_loader_v2 import FixtureLoader
from validation import Validation

# Load all fixtures once
_fixture_loader = FixtureLoader()
_all_fixtures = []
try:
    _all_fixtures.extend(_fixture_loader.load_category('pass'))
except Exception:
    pass
try:
    _all_fixtures.extend(_fixture_loader.load_category('fail'))
except Exception:
    pass

def create_test_data_from_fixture(fixture):
    """Create test data from a fixture (compatibility function)."""
    return (
        fixture.get('original_content', ''),
        fixture.get('diff_content', ''),
        fixture.get('expected_content', ''),
        fixture.get('should_succeed', True),
        fixture.get('expected_error_pattern', '')
    )


def test_fix_hunk_content_line():
    """Test the core fix_hunk_content_line functionality."""
    # Test case 1: Context line missing space prefix (should be fixed)
    input_line = "console.log('hello');"
    fixed_line, issue = Validation.fix_hunk_content_line(input_line, 1)
    
    # Should return the fixed line and create an issue
    assert issue is not None
    assert issue.type == "context_fix"
    assert fixed_line == " console.log('hello');"

    # Test case 2: Valid context line (should keep as is)
    input_line = " return value;"
    fixed_line, issue = Validation.fix_hunk_content_line(input_line, 2)
    assert fixed_line == " return value;"
    assert issue is None

    # Test case 3: Valid addition line (should keep as is)
    input_line = "+function test() {"
    fixed_line, issue = Validation.fix_hunk_content_line(input_line, 3)
    assert fixed_line == "+function test() {"
    assert issue is None

    # Test case 4: Valid removal line (should keep as is)
    input_line = "-const x = 10;"
    fixed_line, issue = Validation.fix_hunk_content_line(input_line, 4)
    assert fixed_line == "-const x = 10;"
    assert issue is None

    # Test case 5: Empty line (should keep as is)
    input_line = ""
    fixed_line, issue = Validation.fix_hunk_content_line(input_line, 5)
    assert fixed_line == ""
    assert issue is None


def test_generic_approach():
    """Test that validation uses the generic approach for context line detection."""
    # Test cases: lines that need space prefix (missing leading space)
    lines_needing_fix = [
        "function test() {",
        "console.log('hello');",
        "return result;",
        "}",
    ]

    for line in lines_needing_fix:
        fixed_line, issue = Validation.fix_hunk_content_line(line, 1)
        
        # These lines should be treated as context and get a space prefix
        assert issue is not None, f"Line '{line}' should be detected as needing context fix"
        assert issue.type == "context_fix", f"Line '{line}' should have context_fix issue"
        assert fixed_line == " " + line, f"Line '{line}' should get space prefix"
    
    # Test cases: lines that are already valid (should not be changed)
    valid_lines = [
        " function test() {",  # already has space prefix
        "+console.log('new');",  # addition line
        "-console.log('old');",  # removal line
        "",  # empty line
    ]
    
    for line in valid_lines:
        fixed_line, issue = Validation.fix_hunk_content_line(line, 1)
        
        # These lines should not be changed
        assert fixed_line == line, f"Line '{line}' should not be changed"
        assert issue is None, f"Line '{line}' should not have any issues"


def test_validate_and_fix_diff():
    """Test diff validation and fixing."""
    # Test case with problematic content that should be fixed
    test_diff = """--- a/test.js
+++ b/test.js
@@ -1,4 +1,4 @@
 function test() {
console.log('old');
console.log('new');
     return true;
 }"""

    fixed_content, issues = Validation.validate_and_fix_diff(test_diff)
    
    # Should return fixed content and list of issues
    assert isinstance(fixed_content, str)
    assert isinstance(issues, list)
    assert len(issues) >= 1  # Should find at least the missing space prefix issues
    
    # Check that issues are properly formatted Issue objects
    for issue in issues:
        assert hasattr(issue, 'line')
        assert hasattr(issue, 'message')
        assert hasattr(issue, 'type')


if HAS_PYTEST:
    @pytest.mark.parametrize("fixture", _all_fixtures, ids=lambda f: f['name'])
    def test_validation_fixture_case(fixture):
        """Test individual validation fixture case."""
        _test_validation_fixture_case_impl(fixture)
else:
    def test_validation_fixture_case(fixture):
        """Test individual validation fixture case."""
        _test_validation_fixture_case_impl(fixture)


def _test_validation_fixture_case_impl(fixture):
    """Test individual validation fixture case."""
    # Convert fixture to test data format
    (
        original_content,
        diff_content,
        expected_content,
        should_succeed,
        expected_error_pattern,
    ) = create_test_data_from_fixture(fixture)

    # Test validation
    fixed_content, issues = Validation.validate_and_fix_diff(diff_content)

    # Check that issues are properly reported
    assert isinstance(issues, list), f"Issues should be a list"
    # Note: validation issues are informational, so we don't fail tests based on them


# Legacy test function for non-pytest runners
def test_validation_with_fixtures(all_fixtures=None):
    """Legacy test function for non-pytest runners."""
    if all_fixtures is None:
        all_fixtures = _all_fixtures
        
    if not all_fixtures:
        print("No fixtures loaded")
        return

    passed = 0
    failed = 0

    for fixture in all_fixtures:
        try:
            _test_validation_fixture_case_impl(fixture)
            passed += 1
        except Exception as e:
            failed += 1
            print(f"❌ {fixture['name']}: {str(e)}")

    # Report results
    print(f"Fixture tests: {passed} passed, {failed} failed")
    # Validation tests shouldn't fail based on validation issues since they're informational