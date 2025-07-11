return {
  name = 'Line Removal',
  description = 'Test removing a line from an existing file',
  should_succeed = true,
  tags = { 'basic', 'removal' },

  original_content = [[
import sys
import os
import json
import re

def main():
    pass
]],

  diff_content = [[
--- a/script.py
+++ b/script.py
@@ -1,7 +1,6 @@
 import sys
 import os
 import json
-import re
 
 def main():
     pass
]],

  expected_content = [[
import sys
import os
import json

def main():
    pass
]],

  file_path = 'script.py',
}
