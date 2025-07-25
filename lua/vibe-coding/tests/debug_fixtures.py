#!/usr/bin/env python3

import sys
import os
sys.path.insert(0, '../python_impl')

from fixture_loader_v2 import FixtureLoader

# Test fixture loading
loader = FixtureLoader()

print("Testing fixture loading...")
print(f"Fixtures directory: {loader.fixtures_dir}")
print(f"Directory exists: {loader.fixtures_dir.exists()}")

if loader.fixtures_dir.exists():
    print(f"Contents: {list(loader.fixtures_dir.iterdir())}")

try:
    # Try to load a single fixture
    fixture = loader.load_fixture('pass/line_addition')
    print(f"Loaded fixture: {fixture['name']}")
    print(f"Original content length: {len(fixture.get('original_content', ''))}")
    print(f"Diff content length: {len(fixture.get('diff_content', ''))}")
    print(f"Expected content length: {len(fixture.get('expected_content', ''))}")
    
    if fixture.get('diff_content'):
        print("First 100 chars of diff:")
        print(repr(fixture['diff_content'][:100]))
    else:
        print("❌ No diff content!")
        
except Exception as e:
    print(f"❌ Error loading fixture: {e}")
    import traceback
    traceback.print_exc()