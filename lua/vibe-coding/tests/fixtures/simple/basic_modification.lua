return {
  name = 'Basic Line Modification',
  description = 'Test modifying a single line in a simple file',
  should_succeed = true,
  tags = { 'basic', 'modification' },

  original_content = [[
local a = 1
local b = 2
local c = 3
]],

  diff_content = [[
--- a/test.lua
+++ b/test.lua
@@ -1,3 +1,3 @@
 local a = 1
-local b = 2
+local b = 42
 local c = 3
]],

  expected_content = [[
local a = 1
local b = 42
local c = 3
]],

  file_path = 'test.lua',
}
