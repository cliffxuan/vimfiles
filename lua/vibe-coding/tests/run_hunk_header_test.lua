-- Test runner for hunk header issue
package.path = '../?.lua;' .. package.path

-- Mock dependencies
package.loaded['vibe-coding.path_utils'] = {
  looks_like_file = function(line)
    return line:match '%.%w+$' and not line:match '^%s*[%w_]+%s*=' and not line:match '%(' and not line:match '%['
  end,
  resolve_file_path = function(path)
    return path
  end,
}

-- Load validation module
local Validation = require 'vibe-coding.validation'

print '=== Testing Real Hunk Header Issue ===\n'

-- Test case 1: Exact problematic pattern
local problematic_diff = [[--- app/api/v2/cli/main.py
+++ app/api/v2/cli/main.py
@@ -4,7 +4,7 @@

-    all_clusters = []
+    all_cluster_names = []
     platforms: list[PLATFORM] = ["isilon", "vast"]

     for platform in platforms:
@@ -10,7 +10,7 @@clusters = get_clusters(platform)
-            all_clusters.extend(clusters)
+            all_cluster_names.extend(clusters.keys())
             console.print(
                 f"[blue]Found {len(clusters)} {platform.title()} clusters[/blue]"
             )except Exception as e:
             console.print(f"[red]Error fetching {platform.title()} clusters: {e}[/red]")

-    if not all_clusters:
+    if not all_cluster_names:
         console.print("[red]No clusters found, cannot generate type alias[/red]")
         return

     # Sort clusters for consistent output
-    all_clusters.sort()
+    all_cluster_names.sort()]]

print 'Original problematic diff:'
print(problematic_diff)
print '\n--- Running Validation ---'

-- Run the validation pipeline
local fixed_diff, issues = Validation.process_diff(problematic_diff)

print('Issues found: ' .. #issues)
for i, issue in ipairs(issues) do
  print(
    'Issue '
      .. i
      .. ': Line '
      .. issue.line
      .. ' ['
      .. string.upper(issue.severity or 'info')
      .. '] - '
      .. issue.message
  )
end

print '\nFixed diff:'
print(fixed_diff)

-- Check for expected fixes
local has_hunk_header_fix = fixed_diff:match '@@ %-10,7 %+10,7 @@\n%s+clusters = get_clusters'
local has_exception_fix = fixed_diff:match '%)\n%s+except Exception as e:'

print '\n--- Validation Results ---'
print('Hunk header properly separated: ' .. tostring(has_hunk_header_fix ~= nil))
print('Exception line properly separated: ' .. tostring(has_exception_fix ~= nil))

if has_hunk_header_fix and has_exception_fix then
  print '✓ TEST PASSED: All issues were correctly fixed'
else
  print '✗ TEST FAILED: Some issues were not fixed'
end
