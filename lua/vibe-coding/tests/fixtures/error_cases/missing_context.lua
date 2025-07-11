return {
  name = 'Missing Context',
  description = 'Test error when the context lines cannot be found in the file',
  should_succeed = false,
  tags = { 'error', 'context', 'missing' },

  original_content = [[
function greet() {
    console.log("Hello World");
}

function farewell() {
    console.log("Goodbye");
}
]],

  diff_content = [[
--- a/greetings.js
+++ b/greetings.js
@@ -1,3 +1,3 @@
 function greet() {
-    console.log("Hi there");
+    console.log("Hello there");
 }
]],

  expected_error_pattern = 'Could not find this context in the file',
  file_path = 'greetings.js',
}
