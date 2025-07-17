-- Test for smart validation functionality
local validation = require 'vibe-coding.validation'

describe('Smart Validation', function()
  it('should detect function definition joined with docstring', function()
    -- Create a temporary test file
    local test_file_path = '/tmp/test_smart_validation_source.py'
    local test_file_content = [[
def test_get_platform_shares_success(mock_get_clusters, mock_get_cluster_shares):
    """Test successful retrieval of platform shares."""
    from app.utils.share import get_platform_shares
    
    # Mock clusters data
]]

    -- Write the test file
    local file = io.open(test_file_path, 'w')
    file:write(test_file_content)
    file:close()

    -- Create a diff with the formatting issue (joined function definition and docstring)
    local diff_content = '--- '
      .. test_file_path
      .. '\n'
      .. '+++ '
      .. test_file_path
      .. '\n'
      .. '@@ -1,5 +1,5 @@\n'
      .. ' def test_get_platform_shares_success(mock_get_clusters, mock_get_cluster_shares):"""Test successful retrieval of platform shares."""\n'
      .. '     from app.utils.share import get_platform_shares\n'
      .. '     \n'
      .. '     # Mock clusters data'

    print 'Testing diff content:'
    print(diff_content)
    print '\n--- Running smart validation ---'

    -- Test smart validation
    local fixed_diff, issues = validation.smart_validate_against_original(diff_content)

    print('Issues found:', #issues)
    for i, issue in ipairs(issues) do
      print(string.format('Issue %d: Line %d [%s] - %s', i, issue.line, issue.severity or 'info', issue.message))
    end

    print '\nFixed diff:'
    print(fixed_diff)

    -- Assertions
    assert(#issues > 0, 'Should detect formatting issues')

    -- Check if any issue mentions the function definition problem
    local found_formatting_issue = false
    for _, issue in ipairs(issues) do
      if issue.message:match 'Function definition joined with docstring' then
        found_formatting_issue = true
        break
      end
    end

    assert(found_formatting_issue, 'Should detect function definition joined with docstring')

    -- The fixed diff should have both the function definition AND the docstring on separate lines
    assert(
      fixed_diff:match 'def test_get_platform_shares_success.-:\n',
      'Fixed diff should have function definition on its own line'
    )
    assert(
      fixed_diff:match '"""Test successful retrieval of platform shares."""',
      'Fixed diff should preserve the docstring'
    )

    -- Clean up
    os.remove(test_file_path)
  end)

  it('should work with the full validation pipeline', function()
    -- Create a temporary test file
    local test_file_path = '/tmp/test_pipeline_source.py'
    local test_file_content = [[
def test_function(param1, param2):
    """Test function docstring."""
    return param1 + param2
]]

    -- Write the test file
    local file = io.open(test_file_path, 'w')
    file:write(test_file_content)
    file:close()

    -- Create a diff with joined function and docstring (common LLM error)
    local diff_content = '--- '
      .. test_file_path
      .. '\n'
      .. '+++ '
      .. test_file_path
      .. '\n'
      .. '@@ -1,3 +1,3 @@\n'
      .. 'def test_function(param1, param2):"""Test function docstring."""\n'
      .. '    return param1 + param2'

    print '\nTesting full pipeline with:'
    print(diff_content)

    -- Test the full validation pipeline
    local fixed_diff, issues = validation.process_diff(diff_content)

    print('\nPipeline issues found:', #issues)
    for i, issue in ipairs(issues) do
      print(string.format('Issue %d: Line %d [%s] - %s', i, issue.line, issue.severity or 'info', issue.message))
    end

    print '\nPipeline fixed diff:'
    print(fixed_diff)

    -- The pipeline should detect and fix the formatting issue
    local found_smart_validation = false
    for _, issue in ipairs(issues) do
      if issue.message:match 'Function definition joined with docstring' then
        found_smart_validation = true
        break
      end
    end

    assert(found_smart_validation, 'Full pipeline should detect smart validation issues')

    -- Clean up
    os.remove(test_file_path)
  end)
end)
