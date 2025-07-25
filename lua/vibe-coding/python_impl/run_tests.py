#!/usr/bin/env python3
"""
Run all Python implementation tests.
This script can be used instead of pytest for running tests.
"""

import sys
from pathlib import Path

# Add current directory to path
sys.path.insert(0, str(Path(__file__).parent))


def run_tests():
    """Run all test modules."""
    print("=" * 60)
    print("Running Python Implementation Tests")
    print("=" * 60)

    # Import and run test modules
    test_modules = [
        "tests.test_validation",
        "tests.test_patcher",
        "tests.test_python_implementation",
    ]

    total_tests = 0
    passed_tests = 0

    for module_name in test_modules:
        try:
            print(f"\n📋 Running {module_name}...")
            module = __import__(module_name, fromlist=[""])

            # Get all test functions
            test_functions = [name for name in dir(module) if name.startswith("test_")]

            for test_func_name in test_functions:
                # Skip parametrized test functions that don't take fixtures
                if test_func_name in ['test_fixture_case', 'test_patcher_fixture_case', 'test_validation_fixture_case']:
                    continue
                    
                total_tests += 1
                test_func = getattr(module, test_func_name)

                try:
                    # Special handling for fixture-based tests
                    if "fixture" in test_func_name.lower():
                        # Load fixtures
                        from fixture_loader_v2 import FixtureLoader

                        loader = FixtureLoader()
                        all_fixtures = []
                        try:
                            all_fixtures.extend(loader.load_category("pass"))
                        except Exception:
                            pass
                        try:
                            all_fixtures.extend(loader.load_category("fail"))
                        except Exception:
                            pass

                        test_func(all_fixtures)
                    else:
                        test_func()

                    print(f"  ✅ {test_func_name}")
                    passed_tests += 1

                except Exception as e:
                    print(f"  ❌ {test_func_name}: {str(e)}")

        except Exception as e:
            print(f"❌ Failed to import {module_name}: {e}")

    print("\n" + "=" * 60)
    print(f"📊 Test Results: {passed_tests}/{total_tests} passed")

    if passed_tests == total_tests:
        print("🎉 All tests passed!")
        return 0
    else:
        print(f"💥 {total_tests - passed_tests} tests failed")
        return 1


if __name__ == "__main__":
    sys.exit(run_tests())
