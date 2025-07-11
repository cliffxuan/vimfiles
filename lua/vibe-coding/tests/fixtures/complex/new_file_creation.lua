return {
  name = 'New File Creation',
  description = 'Test creating a new file when old_path is /dev/null',
  should_succeed = true,
  tags = { 'complex', 'new-file', 'creation' },

  original_content = '', -- Not used for new file creation

  diff_content = [[
--- /dev/null
+++ b/new_script.sh
@@ -0,0 +1,6 @@
+#!/bin/bash
+echo "This is a new script"
+
+# Add some functionality
+DATE=$(date)
+echo "Current date: $DATE"
]],

  expected_content = [[
#!/bin/bash
echo "This is a new script"

# Add some functionality
DATE=$(date)
echo "Current date: $DATE"
]],

  file_path = 'new_script.sh',
}
