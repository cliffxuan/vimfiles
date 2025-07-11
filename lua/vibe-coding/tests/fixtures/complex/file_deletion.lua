return {
  name = 'File Deletion',
  description = 'Test handling file deletion when new_path is /dev/null',
  should_succeed = true,
  tags = { 'complex', 'deletion', 'skip' },

  original_content = [[
#!/bin/bash
echo "This file will be deleted"
exit 0
]],

  diff_content = [[
--- a/old_script.sh
+++ /dev/null
@@ -1,3 +0,0 @@
-#!/bin/bash
-echo "This file will be deleted"
-exit 0
]],

  expected_content = 'Skipped file deletion for old_script.sh', -- Special case: expect success message

  file_path = 'old_script.sh',
}
