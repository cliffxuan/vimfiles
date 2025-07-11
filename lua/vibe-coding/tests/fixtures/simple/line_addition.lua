return {
  name = 'Line Addition',
  description = 'Test adding a line to an existing file',
  should_succeed = true,
  tags = { 'basic', 'addition' },

  original_content = [[
function hello()
  print("Hello")
end
]],

  diff_content = [[
--- a/hello.lua
+++ b/hello.lua
@@ -1,3 +1,4 @@
 function hello()
   print("Hello")
+  print("World")
 end
]],

  expected_content = [[
function hello()
  print("Hello")
  print("World")
end
]],

  file_path = 'hello.lua',
}
