return {
  name = 'Simple Edge Case',
  description = 'Test adding lines with special characters and empty lines',
  should_succeed = true,
  tags = { 'complex', 'edge-cases' },

  original_content = [[
server:
  host: localhost
  port: 8080

logging:
  level: info
]],

  diff_content = [[
--- a/config.yml
+++ b/config.yml
@@ -2,5 +2,7 @@
   host: localhost
   port: 8080
+  ssl: ${SSL_ENABLED}
 
 logging:
   level: info
+  format: json
]],

  expected_content = [[server:
  host: localhost
  port: 8080
  ssl: ${SSL_ENABLED}

logging:
  level: info
  format: json
]],

  file_path = 'config.yml',
}
