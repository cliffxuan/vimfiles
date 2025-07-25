#!/usr/bin/env python3
"""
Python fixture loader that can read Lua-based test fixtures.
Provides cross-language compatibility with the existing Lua fixture system.
"""

import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class FixtureLoader:
    """Loads test fixtures from the Lua-based fixture system."""

    def __init__(self, fixtures_dir: Optional[str] = None):
        """Initialize the fixture loader.

        Args:
            fixtures_dir: Path to fixtures directory. If None, auto-detects based on this file's location.
        """
        if fixtures_dir is None:
            # Auto-detect fixtures directory relative to this file
            current_dir = Path(__file__).parent
            self.fixtures_dir = current_dir.parent / "tests" / "fixtures"
        else:
            self.fixtures_dir = Path(fixtures_dir)

        if not self.fixtures_dir.exists():
            raise FileNotFoundError(
                f"Fixtures directory not found: {self.fixtures_dir}"
            )

    def _parse_lua_fixture(self, lua_content: str) -> Dict[str, Any]:
        """Parse a Lua fixture file and extract the fixture data.

        Args:
            lua_content: Content of the Lua fixture file

        Returns:
            Dictionary containing the fixture data
        """
        # Remove 'return ' prefix and trailing commas/semicolons
        lua_content = lua_content.strip()
        if lua_content.startswith("return "):
            lua_content = lua_content[7:]

        # Parse the Lua table structure
        fixture = {}

        # Extract simple string/boolean/number fields
        patterns = {
            "name": r"name\s*=\s*['\"]([^'\"]*)['\"]",
            "description": r"description\s*=\s*['\"]([^'\"]*)['\"]",
            "should_succeed": r"should_succeed\s*=\s*(true|false)",
            "file_path": r"file_path\s*=\s*['\"]([^'\"]*)['\"]",
            "expected_error_pattern": r"expected_error_pattern\s*=\s*['\"]([^'\"]*)['\"]",
            "original_content_file": r"original_content_file\s*=\s*['\"]([^'\"]*)['\"]",
            "diff_content_file": r"diff_content_file\s*=\s*['\"]([^'\"]*)['\"]",
            "expected_content_file": r"expected_content_file\s*=\s*['\"]([^'\"]*)['\"]",
            "original_content": r"original_content\s*=\s*['\"]([^'\"]*)['\"]",  # Include single-line original_content
        }

        # Also check for single-line expected_content assignments
        expected_content_single = re.search(
            r"expected_content\s*=\s*['\"]([^'\"]*)['\"]", lua_content
        )
        if expected_content_single:
            fixture["expected_content"] = expected_content_single.group(1)

        for field, pattern in patterns.items():
            match = re.search(pattern, lua_content)
            if match:
                value = match.group(1)
                if field == "should_succeed":
                    fixture[field] = value == "true"
                else:
                    fixture[field] = value

        # Extract tags array
        tags_match = re.search(r"tags\s*=\s*\{([^}]*)\}", lua_content)
        if tags_match:
            tags_content = tags_match.group(1)
            tags = re.findall(r"['\"]([^'\"]*)['\"]", tags_content)
            fixture["tags"] = tags

        # Extract multi-line string content (using [[ ]] syntax)
        content_patterns = {
            "original_content": r"original_content\s*=\s*\[\[(.*?)\]\]",
            "diff_content": r"diff_content\s*=\s*\[\[(.*?)\]\]",
            "expected_content": r"expected_content\s*=\s*\[\[(.*?)\]\]",
        }

        for field, pattern in content_patterns.items():
            match = re.search(pattern, lua_content, re.DOTALL)
            if match:
                content = match.group(1)
                # Trim leading/trailing newlines (similar to Lua trim_content function)
                content = re.sub(r"^\s*\n", "", content)
                content = re.sub(r"\n\s*$", "", content)
                fixture[field] = content

        return fixture

    def _load_external_content(self, fixture_dir: Path, filename: str) -> Optional[str]:
        """Load content from an external text file.

        Args:
            fixture_dir: Directory containing the fixture
            filename: Name of the text file to load

        Returns:
            Content of the file, or None if file doesn't exist
        """
        content_path = fixture_dir / filename
        if not content_path.exists():
            return None

        with open(content_path, "r", encoding="utf-8") as f:
            return f.read()

    def _try_load_conventional_content(
        self, fixture_dir: Path, fixture_name: str, content_type: str
    ) -> Optional[str]:
        """Try to load external content using convention-based naming.

        Args:
            fixture_dir: Directory containing the fixture
            fixture_name: Base name of the fixture (without .lua extension)
            content_type: Type of content ('original', 'diff', 'expected')

        Returns:
            Content of the file, or None if file doesn't exist
        """
        filename = f"{fixture_name}_{content_type}.txt"
        return self._load_external_content(fixture_dir, filename)

    def _validate_fixture(self, fixture: Dict[str, Any], fixture_path: str) -> None:
        """Validate fixture structure.

        Args:
            fixture: The fixture data to validate
            fixture_path: Path for error reporting

        Raises:
            ValueError: If fixture is invalid
        """
        # Required fields
        required_fields = ["name", "description", "should_succeed"]

        for field in required_fields:
            if field not in fixture:
                raise ValueError(
                    f'Missing required field "{field}" in fixture: {fixture_path}'
                )

        # Content fields - must have content after loading (but can be empty string)
        if "original_content" not in fixture:
            raise ValueError(
                f'Missing required "original_content" in fixture: {fixture_path}'
            )

        if "diff_content" not in fixture:
            raise ValueError(
                f'Missing required "diff_content" in fixture: {fixture_path}'
            )

        # Type validation
        if not isinstance(fixture["name"], str):
            raise ValueError(
                f'Field "name" must be a string in fixture: {fixture_path}'
            )

        if not isinstance(fixture["description"], str):
            raise ValueError(
                f'Field "description" must be a string in fixture: {fixture_path}'
            )

        if not isinstance(fixture["should_succeed"], bool):
            raise ValueError(
                f'Field "should_succeed" must be a boolean in fixture: {fixture_path}'
            )

        # Conditional validation
        if fixture["should_succeed"]:
            if "expected_content" not in fixture:
                raise ValueError(
                    f'Missing required "expected_content" when should_succeed=True in fixture: {fixture_path}'
                )
        else:
            if "expected_error_pattern" not in fixture:
                raise ValueError(
                    f'Field "expected_error_pattern" is required when should_succeed=False in fixture: {fixture_path}'
                )

    def load_fixture(self, fixture_path: str) -> Dict[str, Any]:
        """Load a single fixture file.

        Args:
            fixture_path: Path relative to fixtures directory (e.g., 'simple/basic_modification')

        Returns:
            The fixture data dictionary
        """
        # Remove .lua extension if provided
        clean_path = fixture_path
        if clean_path.endswith(".lua"):
            clean_path = clean_path[:-4]

        full_path = self.fixtures_dir / f"{clean_path}.lua"

        if not full_path.exists():
            raise FileNotFoundError(f"Fixture file not found: {full_path}")

        # Load and parse the Lua fixture file
        with open(full_path, "r", encoding="utf-8") as f:
            lua_content = f.read()

        fixture = self._parse_lua_fixture(lua_content)

        # Get the directory containing this fixture file and fixture name
        fixture_dir = full_path.parent
        fixture_name = full_path.stem

        # Load content from external files if specified (takes priority over inline content)
        for content_type in ["original", "diff", "expected"]:
            content_file_key = f"{content_type}_content_file"
            content_key = f"{content_type}_content"

            if content_file_key in fixture:
                # Explicit external file specified
                content = self._load_external_content(
                    fixture_dir, fixture[content_file_key]
                )
                if content is None:
                    raise FileNotFoundError(
                        f"External {content_type} content file not found: {fixture_dir}/{fixture[content_file_key]}"
                    )
                fixture[content_key] = content
            elif content_key not in fixture:
                # Try convention-based loading: {fixture_name}_{content_type}.txt
                content = self._try_load_conventional_content(
                    fixture_dir, fixture_name, content_type
                )
                if content is not None:
                    fixture[content_key] = content

        # Validate fixture structure
        self._validate_fixture(fixture, fixture_path)

        # Add metadata
        fixture["_path"] = fixture_path
        fixture["_full_path"] = str(full_path)

        return fixture

    def load_category(self, category: str) -> List[Dict[str, Any]]:
        """Load all fixtures from a category directory.

        Args:
            category: Category name (e.g., 'simple', 'complex', 'error_cases')

        Returns:
            List of fixture data dictionaries
        """
        category_dir = self.fixtures_dir / category

        if not category_dir.exists():
            raise FileNotFoundError(f"Category directory not found: {category_dir}")

        fixtures = []
        lua_files = list(category_dir.glob("*.lua"))

        for lua_file in lua_files:
            fixture_name = lua_file.stem
            fixture_path = f"{category}/{fixture_name}"

            try:
                fixture = self.load_fixture(fixture_path)
                fixtures.append(fixture)
            except Exception as e:
                raise RuntimeError(
                    f"Failed to load fixture: {fixture_path}\nError: {e}"
                )

        # Sort by name for consistent ordering
        fixtures.sort(key=lambda x: x["name"])

        return fixtures

    def load_all(self) -> List[Dict[str, Any]]:
        """Load all fixtures from all categories.

        Returns:
            List of all fixture data dictionaries organized by category
        """
        categories = ["simple", "complex", "error_cases", "integration"]
        all_fixtures = []

        for category in categories:
            try:
                category_fixtures = self.load_category(category)
                for fixture in category_fixtures:
                    fixture["_category"] = category
                    all_fixtures.append(fixture)
            except FileNotFoundError:
                # Category might not exist, skip it
                continue

        return all_fixtures

    def get_categories(self) -> List[str]:
        """Get all available categories.

        Returns:
            List of category names
        """
        categories = []

        for item in self.fixtures_dir.iterdir():
            if item.is_dir() and not item.name.startswith("."):
                categories.append(item.name)

        categories.sort()
        return categories


def create_test_data_from_fixture(
    fixture: Dict[str, Any],
) -> Tuple[str, str, str, bool, Optional[str]]:
    """Convert fixture data to format used by Python tests.

    Args:
        fixture: Fixture data dictionary

    Returns:
        Tuple of (original_content, diff_content, expected_content, should_succeed, expected_error_pattern)
    """
    return (
        fixture["original_content"],
        fixture["diff_content"],
        fixture.get("expected_content", ""),
        fixture["should_succeed"],
        fixture.get("expected_error_pattern"),
    )


# Convenience functions for easy usage
def load_fixture(
    fixture_path: str, fixtures_dir: Optional[str] = None
) -> Dict[str, Any]:
    """Load a single fixture file.

    Args:
        fixture_path: Path relative to fixtures directory
        fixtures_dir: Optional fixtures directory path

    Returns:
        Fixture data dictionary
    """
    loader = FixtureLoader(fixtures_dir)
    return loader.load_fixture(fixture_path)


def load_category(
    category: str, fixtures_dir: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Load all fixtures from a category.

    Args:
        category: Category name
        fixtures_dir: Optional fixtures directory path

    Returns:
        List of fixture data dictionaries
    """
    loader = FixtureLoader(fixtures_dir)
    return loader.load_category(category)


def load_all_fixtures(fixtures_dir: Optional[str] = None) -> List[Dict[str, Any]]:
    """Load all fixtures from all categories.

    Args:
        fixtures_dir: Optional fixtures directory path

    Returns:
        List of all fixture data dictionaries
    """
    loader = FixtureLoader(fixtures_dir)
    return loader.load_all()
