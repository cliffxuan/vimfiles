"""
Language-agnostic fixture loader for directory-based fixtures
Provides utilities to load and manage test fixtures in the new format
"""

import json
from pathlib import Path
from typing import Dict, List, Optional, Any


class FixtureLoader:
    def __init__(self, fixtures_dir: Optional[str] = None):
        if fixtures_dir is None:
            # Default to fixtures directory relative to this file
            self.fixtures_dir = Path(__file__).parent.parent / "tests" / "fixtures"
        else:
            self.fixtures_dir = Path(fixtures_dir)
    
    def load_file_content(self, file_path: Path) -> Optional[str]:
        """Load content from a file."""
        if not file_path.exists() or not file_path.is_file():
            return None
        
        try:
            return file_path.read_text(encoding='utf-8')
        except Exception:
            return None
    
    def load_fixture(self, fixture_path: str) -> Dict[str, Any]:
        """Load a fixture from a directory.
        
        Args:
            fixture_path: Path to fixture directory (e.g., 'pass/basic_modification')
            
        Returns:
            The fixture data as a dictionary
        """
        full_path = self.fixtures_dir / fixture_path
        
        if not full_path.exists() or not full_path.is_dir():
            raise FileNotFoundError(f'Fixture directory not found: {full_path}')
        
        # Load meta.json
        meta_path = full_path / 'meta.json'
        if not meta_path.exists():
            raise FileNotFoundError(f'Fixture meta.json not found: {meta_path}')
        
        with open(meta_path, 'r', encoding='utf-8') as f:
            fixture = json.load(f)
        
        # Load original content
        original_files = list(full_path.glob('original.*'))
        if original_files:
            fixture['original_content'] = self.load_file_content(original_files[0])
        
        # Load diff content
        diff_path = full_path / 'diff'
        fixture['diff_content'] = self.load_file_content(diff_path)
        
        # Load expected content (only for successful tests)
        if fixture.get('should_succeed', False):
            expected_files = list(full_path.glob('expected.*'))
            if expected_files:
                fixture['expected_content'] = self.load_file_content(expected_files[0])
        
        # Validate fixture structure
        self.validate_fixture(fixture, fixture_path)
        
        # Add metadata
        fixture['_path'] = fixture_path
        fixture['_full_path'] = str(full_path)
        
        return fixture
    
    def load_category(self, category: str) -> List[Dict[str, Any]]:
        """Load all fixtures from a category directory.
        
        Args:
            category: Category name (e.g., 'pass', 'fail')
            
        Returns:
            Array of fixture data
        """
        category_dir = self.fixtures_dir / category
        
        if not category_dir.exists() or not category_dir.is_dir():
            raise FileNotFoundError(f'Category directory not found: {category_dir}')
        
        fixtures = []
        
        for item in category_dir.iterdir():
            if item.is_dir():
                fixture_name = item.name
                fixture_path = f"{category}/{fixture_name}"
                
                try:
                    fixture = self.load_fixture(fixture_path)
                    fixtures.append(fixture)
                except Exception as e:
                    raise RuntimeError(f'Failed to load fixture: {fixture_path}\nError: {e}')
        
        # Sort by name for consistent ordering
        fixtures.sort(key=lambda x: x.get('name', ''))
        
        return fixtures
    
    def load_all(self) -> List[Dict[str, Any]]:
        """Load all fixtures from all categories."""
        all_fixtures = []
        
        # Load passing fixtures
        try:
            pass_fixtures = self.load_category('pass')
            for fixture in pass_fixtures:
                fixture['_category'] = 'pass'
                all_fixtures.append(fixture)
        except FileNotFoundError:
            pass  # Category doesn't exist
        
        # Load failing fixtures
        try:
            fail_fixtures = self.load_category('fail')
            for fixture in fail_fixtures:
                fixture['_category'] = 'fail'
                all_fixtures.append(fixture)
        except FileNotFoundError:
            pass  # Category doesn't exist
        
        return all_fixtures
    
    def get_categories(self) -> List[str]:
        """Get all available categories."""
        categories = []
        
        if not self.fixtures_dir.exists():
            return categories
        
        for item in self.fixtures_dir.iterdir():
            if item.is_dir():
                categories.append(item.name)
        
        categories.sort()
        return categories
    
    def validate_fixture(self, fixture: Dict[str, Any], fixture_path: str = 'unknown'):
        """Validate fixture structure."""
        # Required fields
        required_fields = ['name', 'description', 'should_succeed']
        
        for field in required_fields:
            if field not in fixture:
                raise ValueError(f'Missing required field "{field}" in fixture: {fixture_path}')
        
        # Content fields - must have content after loading (allow empty string for new file creation)
        if 'original_content' not in fixture:
            raise ValueError(f'Missing required "original_content" in fixture: {fixture_path}')
        
        if 'diff_content' not in fixture:
            raise ValueError(f'Missing required "diff_content" in fixture: {fixture_path}')
        
        # Type validation
        if not isinstance(fixture['name'], str):
            raise ValueError(f'Field "name" must be a string in fixture: {fixture_path}')
        
        if not isinstance(fixture['description'], str):
            raise ValueError(f'Field "description" must be a string in fixture: {fixture_path}')
        
        if not isinstance(fixture['should_succeed'], bool):
            raise ValueError(f'Field "should_succeed" must be a boolean in fixture: {fixture_path}')
        
        # Conditional validation
        if fixture['should_succeed']:
            if not fixture.get('expected_content'):
                raise ValueError(f'Missing required "expected_content" when should_succeed=true in fixture: {fixture_path}')
        else:
            if not fixture.get('expected_error_pattern'):
                raise ValueError(f'Field "expected_error_pattern" is required when should_succeed=false in fixture: {fixture_path}')


# Global instance for easy importing
fixture_loader = FixtureLoader()

# Convenience functions
def load_fixture(fixture_path: str) -> Dict[str, Any]:
    """Load a fixture from a directory."""
    return fixture_loader.load_fixture(fixture_path)

def load_category(category: str) -> List[Dict[str, Any]]:
    """Load all fixtures from a category directory."""
    return fixture_loader.load_category(category)

def load_all() -> List[Dict[str, Any]]:
    """Load all fixtures from all categories."""
    return fixture_loader.load_all()

def get_categories() -> List[str]:
    """Get all available categories."""
    return fixture_loader.get_categories()