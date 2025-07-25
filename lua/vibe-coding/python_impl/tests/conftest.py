"""
Pytest configuration and shared fixtures for Python implementation tests.
"""

import sys
from pathlib import Path

import pytest

# Add parent directory to path so we can import modules
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

from fixture_loader_v2 import FixtureLoader


@pytest.fixture(scope="session")
def fixture_loader():
    """Shared fixture loader instance."""
    return FixtureLoader()


@pytest.fixture(scope="session")
def all_fixtures(fixture_loader):
    """Load all test fixtures once per session."""
    fixtures = []

    # Load pass fixtures
    try:
        pass_fixtures = fixture_loader.load_category("pass")
        fixtures.extend(pass_fixtures)
    except Exception as e:
        pytest.skip(f"Could not load pass fixtures: {e}")

    # Load fail fixtures
    try:
        fail_fixtures = fixture_loader.load_category("fail")
        fixtures.extend(fail_fixtures)
    except Exception as e:
        print(f"Warning: Could not load fail fixtures: {e}")

    return fixtures


def create_test_data_from_fixture(fixture):
    """Create test data from a fixture (compatibility function)."""
    return (
        fixture.get("original_content", ""),
        fixture.get("diff_content", ""),
        fixture.get("expected_content", ""),
        fixture.get("should_succeed", True),
        fixture.get("expected_error_pattern", ""),
    )
