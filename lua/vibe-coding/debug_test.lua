local validation = require('vibe-coding.validation')

local mixed_diff = [[--- test.py
+++ test.py
@@ -1,3 +1,3 @@
 valid_context_line
def missing_space_function():
+added_line
-removed_line
#invalid_comment_line]]

print('Input diff:')
print(mixed_diff)
print('---')

local fixed_diff, issues = validation.validate_and_fix_diff(mixed_diff)

print('Fixed diff:')
print(fixed_diff)
print('---')

print('Issues:', #issues)
for i, issue in ipairs(issues) do
  print(i, issue.type, issue.message)
end

print('---')
print('Does it match the function?', string.find(fixed_diff, ' def missing_space_function():') ~= nil)
print('Does it match the comment?', string.find(fixed_diff, '#invalid_comment_line') ~= nil)